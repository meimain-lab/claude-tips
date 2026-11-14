import AppKit
import SwiftUI
import TipsCore

/// A segment of the popover: one of the three content groups, or 未整理.
enum Segment: Hashable {
    case group(TipGroup)
    case unsorted

    func title(in language: TipLanguage) -> String {
        switch self {
        case .group(let group): return group.title(in: language)
        case .unsorted: return UIText.of(language).unsorted
        }
    }

    /// The segment bar holds four labels in 360 pt, so English uses shorter
    /// ones there; the full group names fit everywhere else.
    func barTitle(in language: TipLanguage) -> String {
        switch (self, language) {
        case (.group(.say), .en): return "Say it"
        case (.group(.slash), .en): return "Slash"
        case (.unsorted, .en): return "Other"
        default: return title(in: language)
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
    case toggleLanguage
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
    /// The chosen view; remembered across launches when the model has defaults.
    @Published private(set) var language: TipLanguage
    /// The id of the row showing 已复制 right now.
    @Published private(set) var copiedId: String?
    /// Bumped on every open so the search field takes focus again.
    @Published private(set) var focusToken = 0

    /// Called after a copy, once the 已复制 label has been shown.
    var onCopied: (() -> Void)?

    private let locations: TipsLocations
    private let defaults: UserDefaults?
    static let languageKey = "language"

    /// `defaults` nil keeps the language for this run only (the snapshot tool uses that).
    init(locations: TipsLocations, defaults: UserDefaults? = .standard) {
        self.locations = locations
        self.defaults = defaults
        let saved = defaults?.string(forKey: Self.languageKey).flatMap(TipLanguage.init(rawValue:))
        self.language = saved ?? .zh
    }

    var text: UIText { UIText.of(language) }

    /// Switches the view and remembers it; an open detail redraws in the new language.
    func setLanguage(_ newLanguage: TipLanguage) {
        guard newLanguage != language else { return }
        language = newLanguage
        defaults?.set(newLanguage.rawValue, forKey: Self.languageKey)
        if let shown = detailTip {
            detailTip = (library.tips + library.unsorted).first { $0.id == shown.id }?.localized(newLanguage)
        }
    }

    func toggleLanguage() {
        setLanguage(language == .zh ? .en : .zh)
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
        let rows: [Tip]
        switch segment {
        case .group(let group): rows = library.tips(in: group)
        case .unsorted: rows = library.unsorted
        }
        return rows.map { $0.localized(language) }
    }

    /// The rows the list shows: search results across all groups, or the current segment.
    var visibleTips: [Tip] {
        if isSearching {
            return searchTips((library.tips + library.unsorted).map { $0.localized(language) }, query: query)
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
        // Every open starts on 直接说, like a fresh launch.
        segment = .group(.say)
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
        case .toggleLanguage:
            toggleLanguage()
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
