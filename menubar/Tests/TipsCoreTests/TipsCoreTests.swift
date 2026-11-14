import Foundation
import Testing
@testable import TipsCore

private func tip(_ id: String, title: String? = nil, copy: String? = nil, keywords: [String] = [],
                 sourceKind: String = "builtin-skill", sourceName: String? = nil) -> Tip {
    Tip(id: id, group: .say, title: title ?? "标题 \(id)", copy: copy ?? "copy \(id)",
        keywords: keywords, sourceKind: sourceKind, sourceName: sourceName ?? id)
}

private func json(_ object: Any) -> Data {
    try! JSONSerialization.data(withJSONObject: object)
}

@Suite struct ParsingTests {
    @Test func brokenJSONIsReportedAndDoesNotThrow() {
        let parsed = parseTipsFile(Data(#"{"version": 1, "tips": ["#.utf8))
        #expect(parsed.isBroken)
        #expect(parsed.tips.isEmpty)
        #expect(parseTipsFile(Data("[]".utf8)).isBroken)
    }

    @Test func missingFileIsNotBroken() {
        let parsed = parseTipsFile(nil)
        #expect(parsed.isMissing)
        #expect(!parsed.isBroken)
    }

    @Test func badEntriesAreSkippedAndCounted() {
        let parsed = parseTipsFile(json(["version": 1, "tips": [
            ["id": "good", "group": "say", "title": "好的", "copy": "Good."],
            ["id": "no-copy", "group": "say", "title": "没有原文"],
            ["id": "bad-group", "group": "other", "title": "分组不对", "copy": "x"],
            "not an object",
            ["id": "gone", "hidden": true],
        ]]))
        #expect(parsed.tips.map(\.id) == ["good"])
        #expect(parsed.skipped == 3)
        #expect(parsed.hiddenIds == ["gone"])
    }

    @Test func realContentFileParses() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("content/tips.json")
        let parsed = parseTipsFile(try Data(contentsOf: url))
        #expect(parsed.tips.count == 13)
        #expect(parsed.skipped == 0)
    }
}

@Suite struct MergeTests {
    @Test func localReplacesInPlaceAndAppends() {
        let local = parseTipsFile(json(["version": 1, "tips": [
            ["id": "mine-1", "group": "mine", "title": "我的一条", "copy": "/mine-1"],
            ["id": "b", "group": "say", "title": "本机改写", "copy": "Local b."],
        ]]))
        let merged = mergeTips(public: [tip("a"), tip("b"), tip("c")], local: local)
        #expect(merged.map(\.id) == ["a", "b", "c", "mine-1"])
        #expect(merged[1].copy == "Local b.")
    }

    @Test func hiddenRemovesPublicTip() {
        let local = parseTipsFile(json(["version": 1, "tips": [["id": "b", "hidden": true]]]))
        #expect(mergeTips(public: [tip("a"), tip("b")], local: local).map(\.id) == ["a"])
    }
}

@Suite struct SearchTests {
    let tips = [
        tip("copy-hit", title: "其他", copy: "Make a chart now"),
        tip("keyword-hit", title: "画个东西", keywords: ["Chart"]),
        tip("title-contains", title: "数据 chart 图"),
        tip("title-prefix", title: "Chart 优先"),
        tip("no-hit", title: "无关"),
    ]

    @Test func ranksAndIgnoresCase() {
        #expect(searchTips(tips, query: "CHART").map(\.id)
            == ["title-prefix", "title-contains", "keyword-hit", "copy-hit"])
    }

    @Test func keepsFileOrderAndEmptyQueryReturnsAll() {
        let same = [tip("one", title: "图表一"), tip("two", title: "图表二")]
        #expect(searchTips(same, query: "图表").map(\.id) == ["one", "two"])
        #expect(searchTips(tips, query: "  ").count == tips.count)
        #expect(searchTips(tips, query: "画个").map(\.id) == ["keyword-hit"])
    }
}

@Suite struct SkillScanTests {
    @Test func readsFrontmatterValues() {
        let plain = readFrontmatter("---\nname: alpha\ndescription: \"Does a thing\"\n---\nbody")
        #expect(plain.name == "alpha")
        #expect(plain.description == "Does a thing")
        let folded = readFrontmatter("---\nname: beta\ndescription: >\n  First line\n  second line\n---\n")
        #expect(folded.description == "First line second line")
        #expect(readFrontmatter("no frontmatter").name == nil)
    }

    @Test func marksMissingAndListsUnsorted() {
        let result = applySkillScan(
            [tip("kept", sourceKind: "user-skill"), tip("gone", sourceKind: "user-skill")],
            skills: [
                SkillInfo(dirName: "kept", name: "kept", description: ""),
                SkillInfo(dirName: "new-one", name: "new-one", description: "A new skill"),
            ])
        #expect(result.tips.map(\.isMissing) == [false, true])
        #expect(result.unsorted.map(\.copy) == ["/new-one"])
        #expect(result.unsorted.first?.detail == "A new skill")
        #expect(result.unsorted.first?.isUnsorted == true)
    }

    @Test func noScanMarksNothing() {
        let result = applySkillScan([tip("x", sourceKind: "user-skill")], skills: nil)
        #expect(result.tips.first?.isMissing == false)
        #expect(result.unsorted.isEmpty)
    }

    @Test func unreadableSymlinkedSkillStillCounts() throws {
        let skills = FileManager.default.temporaryDirectory
            .appendingPathComponent("tips-symlink-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: skills) }
        try FileManager.default.createDirectory(at: skills, withIntermediateDirectories: true)
        // A link whose target cannot be read, as when macOS denies Desktop access.
        try FileManager.default.createSymbolicLink(
            at: skills.appendingPathComponent("linked-skill"),
            withDestinationURL: skills.appendingPathComponent("unreadable-target"))
        try FileManager.default.createDirectory(
            at: skills.appendingPathComponent("plain-folder"), withIntermediateDirectories: true)
        let found = scanSkills(in: skills)
        #expect(found?.map(\.dirName) == ["linked-skill"])
        #expect(found?.first?.name == "linked-skill")
    }
}

@Suite struct LoadingTests {
    private func makeHome() throws -> URL {
        let home = FileManager.default.temporaryDirectory
            .appendingPathComponent("tips-core-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: home.appendingPathComponent(".claude/claude-tips"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: home.appendingPathComponent(".claude/skills/loose-skill"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: home.appendingPathComponent(".claude/skills/no-skill-file"), withIntermediateDirectories: true)
        try Data("---\nname: loose-skill\ndescription: Loose.\n---\n".utf8)
            .write(to: home.appendingPathComponent(".claude/skills/loose-skill/SKILL.md"))
        return home
    }

    private func bundled(in home: URL) throws -> URL {
        let url = home.appendingPathComponent("bundled.json")
        try json(["version": 1, "tips": [
            ["id": "bundled-only", "group": "say", "title": "自带副本", "copy": "Bundled."],
        ]]).write(to: url)
        return url
    }

    @Test func loadsMergesAndScans() throws {
        let home = try makeHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let runtime = home.appendingPathComponent(".claude/claude-tips")
        try json(["version": 1, "tips": [
            ["id": "a", "group": "say", "title": "公开一条", "copy": "A."],
        ]]).write(to: runtime.appendingPathComponent("tips.json"))
        try json(["version": 1, "tips": [
            ["id": "gone", "group": "mine", "title": "删掉的", "copy": "/gone",
             "source": ["kind": "user-skill", "name": "gone"]],
        ]]).write(to: runtime.appendingPathComponent("tips.local.json"))
        let library = loadLibrary(from: .standard(home: home, bundledTips: try bundled(in: home)))
        #expect(library.tips.map(\.id) == ["a", "gone"])
        #expect(library.tips.last?.isMissing == true)
        #expect(library.unsorted.map(\.title) == ["loose-skill"])
        #expect(library.notices.isEmpty)
    }

    @Test func brokenFilesFallBackWithNotices() throws {
        let home = try makeHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let runtime = home.appendingPathComponent(".claude/claude-tips")
        try Data("{".utf8).write(to: runtime.appendingPathComponent("tips.json"))
        try Data("nope".utf8).write(to: runtime.appendingPathComponent("tips.local.json"))
        let library = loadLibrary(from: .standard(home: home, bundledTips: try bundled(in: home)))
        #expect(library.tips.map(\.id) == ["bundled-only"])
        #expect(library.notices.count == 2)
    }

    @Test func missingRuntimeUsesBundledQuietly() throws {
        let home = try makeHome()
        defer { try? FileManager.default.removeItem(at: home) }
        try FileManager.default.removeItem(at: home.appendingPathComponent(".claude/claude-tips"))
        let library = loadLibrary(from: .standard(home: home, bundledTips: try bundled(in: home)))
        #expect(library.tips.map(\.id) == ["bundled-only"])
        #expect(library.notices.isEmpty)
    }
}

/// Rows are 52 pt with 2 pt gaps, and the popover shows six (324 pt), as in PopoverView.
@Suite struct ListOverflowTests {
    private func overflow(rows: Int, offset: Double, viewport: Double = 324) -> ListOverflow {
        ListOverflow(rowCount: rows, rowHeight: 52, spacing: 2, viewportHeight: viewport, offset: offset)
    }

    @Test func fittingListHasNoOverflow() {
        let state = overflow(rows: 5, offset: 0, viewport: 5 * 54)
        #expect(state.isAtTop && state.isAtBottom)
        #expect(state.rowsBelow == 0 && state.rowsAbove == 0)
        #expect(state.firstRowBelow == nil)
    }

    @Test func eightRowsAtTopLeaveTwoBelow() {
        let state = overflow(rows: 8, offset: 0)
        #expect(state.isAtTop && !state.isAtBottom)
        #expect(state.rowsBelow == 2)
        #expect(state.firstRowBelow == 6)
    }

    @Test func countGoesDownWhileScrolling() {
        // Scrolled by just under one row: row 6 is still cut off at the bottom.
        #expect(overflow(rows: 8, offset: 20).rowsBelow == 2)
        // Scrolled one row: row 6 is fully in view, row 7 is not.
        let state = overflow(rows: 8, offset: 54)
        #expect(state.rowsBelow == 1)
        #expect(state.rowsAbove == 1)
        #expect(!state.isAtTop && !state.isAtBottom)
    }

    @Test func atBottomNothingRemains() {
        let contentHeight = 8.0 * 54 - 2
        let state = overflow(rows: 8, offset: contentHeight - 324)
        #expect(state.isAtBottom && !state.isAtTop)
        #expect(state.rowsBelow == 0)
        #expect(state.rowsAbove == 2)
    }

    @Test func overscrollIsClamped() {
        #expect(overflow(rows: 8, offset: -40).isAtTop)
        #expect(overflow(rows: 8, offset: 999).isAtBottom)
        #expect(overflow(rows: 8, offset: 999).rowsBelow == 0)
    }

    @Test func emptyListIsAtBothEdges() {
        let state = overflow(rows: 0, offset: 0)
        #expect(state.isAtTop && state.isAtBottom && state.rowsBelow == 0)
    }
}

@Suite struct ViewportHeightTests {
    private func height(_ rows: Int) -> Double {
        ListOverflow.viewportHeight(rowCount: rows, rowHeight: 52, spacing: 2, visibleRows: 6)
    }

    @Test func fittingListsKeepTheirHeight() {
        #expect(height(0) == 0)
        #expect(height(5) == 5 * 54)
        #expect(height(6) == 6 * 54)
    }

    @Test func overflowingListShowsHalfOfTheNextRow() {
        #expect(height(7) == 6 * 54 + 26)
        #expect(height(20) == 6 * 54 + 26)
        // Seven rows in that viewport: the seventh is cut, so one row remains.
        let state = ListOverflow(rowCount: 7, rowHeight: 52, spacing: 2, viewportHeight: height(7), offset: 0)
        #expect(state.rowsBelow == 1)
        #expect(state.firstRowBelow == 6)
    }
}
