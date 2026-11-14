import AppKit
import SwiftUI
import TipsCore

/// A segment of the popover: one of the three content groups, or 未整理.
enum Segment: Hashable {
    case group(TipGroup)
    case unsorted

    var title: String {
        switch self {
        case .group(let group): return group.title
        case .unsorted: return "未整理"
        }
    }

    var symbolName: String {
        switch self {
        case .group(let group): return group.symbolName
        case .unsorted: return "tray"
        }
    }
}

/// The keys the popover reacts to, decoded from key-down events by the shell.
enum KeyCommand {
    case up, down, enter, right, left, escape
    case segment(Int)
}

/// What the shell should do after a key or a click.
enum KeyOutcome {
    case ignored
    case handled
    case close
}

/// Popover state: the loaded library, the query, the selection and the detail layer.
@MainActor
final class TipsViewModel: ObservableObject {
    @Published private(set) var library = TipLibrary(tips: [], unsorted: [], notices: [])
    @Published var query = "" {
        didSet { if query != oldValue { selectedIndex = 0 } }
    }
    @Published var segment: Segment = .group(.say)
    @Published var selectedIndex = 0
    @Published var detailTip: Tip?
    /// The id of the row showing 已复制 right now.
    @Published private(set) var copiedId: String?
    /// Bumped on every open so the search field takes focus again.
    @Published private(set) var focusToken = 0

    /// Called after a copy, once the 已复制 label has been shown.
    var onCopied: (() -> Void)?

    private let locations: TipsLocations

    init(locations: TipsLocations) {
        self.locations = locations
    }

    var segments: [Segment] {
        var all = TipGroup.allCases.map(Segment.group)
        if !library.unsorted.isEmpty { all.append(.unsorted) }
        return all
    }

    var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func count(of segment: Segment) -> Int {
        tips(in: segment).count
    }

    private func tips(in segment: Segment) -> [Tip] {
        switch segment {
        case .group(let group): return library.tips(in: group)
        case .unsorted: return library.unsorted
        }
    }

    /// The rows the list shows: search results across all groups, or the current segment.
    var visibleTips: [Tip] {
        if isSearching {
            return searchTips(library.tips + library.unsorted, query: query)
        }
        return tips(in: segment)
    }

    var selectedTip: Tip? {
        let rows = visibleTips
        return rows.indices.contains(selectedIndex) ? rows[selectedIndex] : nil
    }

    /// Re-reads the content files; called every time the popover opens.
    func reload() {
        library = loadLibrary(from: locations)
        if !segments.contains(segment) { segment = .group(.say) }
        query = ""
        selectedIndex = 0
        detailTip = nil
        copiedId = nil
        focusToken += 1
    }

    func select(segment newSegment: Segment) {
        segment = newSegment
        query = ""
        selectedIndex = 0
        detailTip = nil
    }

    func handle(_ command: KeyCommand) -> KeyOutcome {
        switch command {
        case .up:
            guard detailTip == nil else { return .handled }
            selectedIndex = max(0, selectedIndex - 1)
            return .handled
        case .down:
            guard detailTip == nil else { return .handled }
            selectedIndex = min(max(0, visibleTips.count - 1), selectedIndex + 1)
            return .handled
        case .enter:
            guard let tip = detailTip ?? selectedTip else { return .handled }
            copy(tip)
            return .handled
        case .right:
            guard detailTip == nil, let tip = selectedTip else { return .ignored }
            detailTip = tip
            return .handled
        case .left:
            guard detailTip != nil else { return .ignored }
            detailTip = nil
            return .handled
        case .escape:
            if isSearching {
                query = ""
                return .handled
            }
            return .close
        case .segment(let number):
            let all = segments
            guard all.indices.contains(number - 1) else { return .handled }
            select(segment: all[number - 1])
            return .handled
        }
    }

    /// Copies the tip's English text, shows 已复制 for about 0.6 s, then asks the shell to close.
    func copy(_ tip: Tip) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(tip.copy, forType: .string)
        copiedId = tip.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self, self.copiedId == tip.id else { return }
            self.onCopied?()
        }
    }
}
