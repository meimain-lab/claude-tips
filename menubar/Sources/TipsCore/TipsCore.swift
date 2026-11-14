import Foundation

/// The three fixed groups of the content file, in display order.
public enum TipGroup: String, CaseIterable, Sendable {
    case say, slash, mine

    public var title: String {
        switch self {
        case .say: return "直接说"
        case .slash: return "斜杠命令"
        case .mine: return "我的"
        }
    }

    /// SF Symbols name for the group's neutral icon.
    public var symbolName: String {
        switch self {
        case .say: return "bubble.left"
        case .slash: return "terminal"
        case .mine: return "star"
        }
    }
}

/// One tip as read from a content file, or one 未整理 skill.
public struct Tip: Equatable, Identifiable, Sendable {
    public var id: String
    public var group: TipGroup
    public var title: String
    public var copy: String
    public var detail: String
    public var keywords: [String]
    public var icon: String
    public var sourceKind: String
    public var sourceName: String
    /// True for a tip whose user skill is no longer on disk.
    public var isMissing: Bool = false
    /// True for a skill found on disk that no tip references.
    public var isUnsorted: Bool = false

    public init(
        id: String, group: TipGroup, title: String, copy: String, detail: String = "",
        keywords: [String] = [], icon: String = "", sourceKind: String = "", sourceName: String = "",
        isMissing: Bool = false, isUnsorted: Bool = false
    ) {
        self.id = id
        self.group = group
        self.title = title
        self.copy = copy
        self.detail = detail
        self.keywords = keywords
        self.icon = icon
        self.sourceKind = sourceKind
        self.sourceName = sourceName
        self.isMissing = isMissing
        self.isUnsorted = isUnsorted
    }
}

/// A parsed content file. Never thrown: problems are counted instead.
public struct ParsedTipsFile: Equatable, Sendable {
    public var tips: [Tip] = []
    public var hiddenIds: [String] = []
    public var skipped = 0
    public var isBroken = false
    public var isMissing = false

    public init() {}
}

public struct SkillInfo: Equatable, Sendable {
    public var dirName: String
    public var name: String
    public var description: String

    public init(dirName: String, name: String, description: String) {
        self.dirName = dirName
        self.name = name
        self.description = description
    }
}

/// Everything a front end draws: merged tips, 未整理 skills and notice lines.
public struct TipLibrary: Equatable, Sendable {
    public var tips: [Tip]
    public var unsorted: [Tip]
    public var notices: [String]

    public init(tips: [Tip], unsorted: [Tip], notices: [String]) {
        self.tips = tips
        self.unsorted = unsorted
        self.notices = notices
    }

    public func tips(in group: TipGroup) -> [Tip] {
        tips.filter { $0.group == group }
    }
}

// MARK: - Parsing

private func text(_ value: Any?) -> String? {
    guard let string = value as? String, !string.trimmingCharacters(in: .whitespaces).isEmpty
    else { return nil }
    return string
}

/// Turns one raw entry into a Tip, or nil when a required field is bad.
public func makeTip(from raw: Any) -> Tip? {
    guard let entry = raw as? [String: Any],
          let id = text(entry["id"]),
          let title = text(entry["title"]),
          let copy = text(entry["copy"]),
          let groupName = entry["group"] as? String,
          let group = TipGroup(rawValue: groupName)
    else { return nil }
    let source = entry["source"] as? [String: Any]
    return Tip(
        id: id,
        group: group,
        title: title,
        copy: copy,
        detail: text(entry["detail"]) ?? "",
        keywords: (entry["keywords"] as? [Any])?.compactMap { text($0) } ?? [],
        icon: text(entry["icon"]) ?? "",
        sourceKind: text(source?["kind"]) ?? "",
        sourceName: text(source?["name"]) ?? ""
    )
}

/// Parses a tips file's bytes; nil data means the file does not exist.
public func parseTipsFile(_ data: Data?) -> ParsedTipsFile {
    var result = ParsedTipsFile()
    guard let data else {
        result.isMissing = true
        return result
    }
    guard let object = try? JSONSerialization.jsonObject(with: data),
          let root = object as? [String: Any],
          let list = root["tips"] as? [Any]
    else {
        result.isBroken = true
        return result
    }
    for raw in list {
        if let entry = raw as? [String: Any], entry["hidden"] as? Bool == true,
           let id = text(entry["id"]) {
            result.hiddenIds.append(id)
            continue
        }
        if let tip = makeTip(from: raw) {
            result.tips.append(tip)
        } else {
            result.skipped += 1
        }
    }
    return result
}

// MARK: - Merging and search

/// Public first, then local: a local tip with the same id replaces the public
/// one in place; a local `hidden: true` entry removes the public tip.
public func mergeTips(public publicTips: [Tip], local: ParsedTipsFile) -> [Tip] {
    let hidden = Set(local.hiddenIds)
    var localById: [String: Tip] = [:]
    for tip in local.tips where localById[tip.id] == nil {
        localById[tip.id] = tip
    }
    var seen = Set<String>()
    var merged: [Tip] = []
    for tip in publicTips where !hidden.contains(tip.id) && !seen.contains(tip.id) {
        seen.insert(tip.id)
        merged.append(localById[tip.id] ?? tip)
    }
    for tip in local.tips where !hidden.contains(tip.id) && !seen.contains(tip.id) {
        seen.insert(tip.id)
        merged.append(tip)
    }
    return merged
}

/// Case-insensitive substring search over title, copy and keywords. Ranked:
/// title prefix, title contains, keyword hit, copy hit; file order within a rank.
public func searchTips(_ tips: [Tip], query: String) -> [Tip] {
    let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if needle.isEmpty { return tips }
    var ranked: [(tip: Tip, rank: Int, index: Int)] = []
    for (index, tip) in tips.enumerated() {
        let title = tip.title.lowercased()
        let rank: Int
        if title.hasPrefix(needle) {
            rank = 0
        } else if title.contains(needle) {
            rank = 1
        } else if tip.keywords.contains(where: { $0.lowercased().contains(needle) }) {
            rank = 2
        } else if tip.copy.lowercased().contains(needle) {
            rank = 3
        } else {
            continue
        }
        ranked.append((tip, rank, index))
    }
    ranked.sort { ($0.rank, $0.index) < ($1.rank, $1.index) }
    return ranked.map(\.tip)
}

// MARK: - Skill scan

/// Reads `name` and `description` from a SKILL.md frontmatter block. Handles
/// plain, quoted, folded (`>`) and literal (`|`) values.
public func readFrontmatter(_ source: String) -> (name: String?, description: String?) {
    let lines = source.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
    guard lines.first?.trimmingCharacters(in: .whitespaces) == "---",
          let end = lines.indices.dropFirst().first(where: {
              lines[$0].trimmingCharacters(in: .whitespaces) == "---"
          })
    else { return (nil, nil) }
    let block = Array(lines[1..<end])
    var found: [String: String] = [:]
    var index = 0
    while index < block.count {
        let line = block[index]
        guard let colon = line.firstIndex(of: ":"), let first = line.first,
              first.isLetter || first == "_"
        else {
            index += 1
            continue
        }
        let key = String(line[..<colon])
        guard key.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }) else {
            index += 1
            continue
        }
        var value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        let isBlock = value.range(of: #"^[>|][+-]?$"#, options: .regularExpression) != nil
        var continued: [String] = []
        while index + 1 < block.count {
            let next = block[index + 1]
            let isIndented = next.first == " " || next.first == "\t"
            if next.trimmingCharacters(in: .whitespaces).isEmpty {
                if !isBlock { break }
            } else if !isIndented {
                break
            }
            continued.append(next.trimmingCharacters(in: .whitespaces))
            index += 1
        }
        if isBlock {
            value = continued.joined(separator: value.hasPrefix("|") ? "\n" : " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } else if !continued.isEmpty {
            value = ([value] + continued).joined(separator: " ")
        }
        if value.count >= 2, let head = value.first, let tail = value.last,
           (head == "\"" && tail == "\"") || (head == "'" && tail == "'") {
            value = String(value.dropFirst().dropLast())
        }
        found[key] = value
        index += 1
    }
    let name = found["name"].flatMap { $0.isEmpty ? nil : $0 }
    let description = found["description"].flatMap { $0.isEmpty ? nil : $0 }
    return (name, description)
}

/// Read-only scan of `<skillsDir>/*/SKILL.md`; nil when the folder cannot be read.
public func scanSkills(in skillsDir: URL, fileManager: FileManager = .default) -> [SkillInfo]? {
    guard let names = try? fileManager.contentsOfDirectory(atPath: skillsDir.path) else {
        return nil
    }
    var skills: [SkillInfo] = []
    for dirName in names.sorted() where !dirName.hasPrefix(".") {
        let entry = skillsDir.appendingPathComponent(dirName)
        let file = entry.appendingPathComponent("SKILL.md")
        let meta: (name: String?, description: String?)
        if let data = fileManager.contents(atPath: file.path),
           let source = String(data: data, encoding: .utf8) {
            meta = readFrontmatter(source)
        } else if isSymbolicLink(entry, fileManager: fileManager) {
            // A symlink into a protected folder (Desktop, Documents) can be
            // unreadable when macOS privacy access is denied. The link itself
            // still says the skill is installed, so keep it under its folder name.
            meta = (nil, nil)
        } else {
            continue
        }
        skills.append(SkillInfo(
            dirName: dirName, name: meta.name ?? dirName, description: meta.description ?? ""
        ))
    }
    return skills
}

private func isSymbolicLink(_ url: URL, fileManager: FileManager) -> Bool {
    let attributes = try? fileManager.attributesOfItem(atPath: url.path)
    return attributes?[.type] as? FileAttributeType == .typeSymbolicLink
}

/// Marks tips whose user skill is gone and lists unreferenced skills as 未整理.
public func applySkillScan(_ tips: [Tip], skills: [SkillInfo]?) -> (tips: [Tip], unsorted: [Tip]) {
    guard let skills else { return (tips, []) }
    var known = Set<String>()
    for skill in skills {
        known.insert(skill.name)
        known.insert(skill.dirName)
    }
    let marked = tips.map { tip -> Tip in
        var copy = tip
        copy.isMissing = tip.sourceKind == "user-skill" && !known.contains(tip.sourceName)
        return copy
    }
    let referenced = Set(tips.map(\.sourceName).filter { !$0.isEmpty })
    let unsorted = skills
        .filter { !referenced.contains($0.name) && !referenced.contains($0.dirName) }
        .map { skill in
            Tip(
                id: "unsorted-\(skill.dirName)", group: .mine, title: skill.name,
                copy: "/\(skill.name)", detail: skill.description, keywords: [skill.dirName],
                sourceKind: "user-skill", sourceName: skill.name, isUnsorted: true
            )
        }
    return (marked, unsorted)
}

// MARK: - Loading

/// Where the content files live. Defaults to `~/.claude/claude-tips/` and `~/.claude/skills/`.
public struct TipsLocations: Sendable {
    public var runtimeDir: URL
    public var skillsDir: URL
    public var bundledTips: URL?

    public init(runtimeDir: URL, skillsDir: URL, bundledTips: URL?) {
        self.runtimeDir = runtimeDir
        self.skillsDir = skillsDir
        self.bundledTips = bundledTips
    }

    public static func standard(home: URL, bundledTips: URL?) -> TipsLocations {
        let claude = home.appendingPathComponent(".claude")
        return TipsLocations(
            runtimeDir: claude.appendingPathComponent("claude-tips"),
            skillsDir: claude.appendingPathComponent("skills"),
            bundledTips: bundledTips
        )
    }
}

/// Reads both content files and the skill folder fresh. Never throws.
public func loadLibrary(from locations: TipsLocations, fileManager: FileManager = .default) -> TipLibrary {
    var notices: [String] = []
    func read(_ url: URL?) -> Data? {
        guard let url else { return nil }
        return fileManager.contents(atPath: url.path)
    }

    var publicFile = parseTipsFile(read(locations.runtimeDir.appendingPathComponent("tips.json")))
    if publicFile.isBroken || publicFile.isMissing {
        if publicFile.isBroken { notices.append("tips.json 无法读取，已改用应用自带的副本") }
        publicFile = parseTipsFile(read(locations.bundledTips))
    }
    var localFile = parseTipsFile(read(locations.runtimeDir.appendingPathComponent("tips.local.json")))
    if localFile.isBroken {
        notices.append("tips.local.json 不是有效的 JSON，已忽略")
        localFile = ParsedTipsFile()
    }
    let skipped = publicFile.skipped + localFile.skipped
    if skipped > 0 { notices.append("跳过 \(skipped) 条字段不全的条目") }

    let merged = mergeTips(public: publicFile.tips, local: localFile)
    let scanned = applySkillScan(merged, skills: scanSkills(in: locations.skillsDir, fileManager: fileManager))
    return TipLibrary(tips: scanned.tips, unsorted: scanned.unsorted, notices: notices)
}
