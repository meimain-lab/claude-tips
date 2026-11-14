import AppKit
import SwiftUI
import TipsCore

/// Development aid: `ClaudeTipsMenuBar --snapshot <dir>` renders the popover
/// offscreen in light and dark (list, search and detail states) as PNG files,
/// so the look can be checked without opening the menu bar. Reads the same
/// content files as the app; nothing is written anywhere but `<dir>`.
@MainActor
enum Snapshot {
    static func run(into directory: URL) {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let bundled = Bundle.main.url(forResource: "tips", withExtension: "json")
        // No defaults: the snapshot never reads or changes the saved language.
        let model = TipsViewModel(locations: .standard(home: home, bundledTips: bundled), defaults: nil)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        // Each state: name, setup before the first layout, and a change applied
        // after it (so onChange handlers such as scrolling run as in the app).
        let states: [(String, (TipsViewModel) -> Void, ((TipsViewModel) -> Void)?)] = [
            ("list", { $0.setLanguage(.zh); $0.reload() }, nil),
            ("slash", { $0.reload(); _ = $0.handle(.segment(2)); _ = $0.handle(.down) }, nil),
            ("overflow-top", { $0.reload(); _ = $0.handle(.segment(2)) }, nil),
            ("overflow-bottom", { $0.reload(); _ = $0.handle(.segment(2)) }, { model in
                model.selectedIndex = max(0, model.visibleTips.count - 1)
            }),
            ("search", { $0.reload(); $0.query = "图" }, nil),
            ("no-results", { $0.reload(); $0.query = "zzzz" }, nil),
            ("detail", { $0.reload(); _ = $0.handle(.right) }, nil),
            ("list-en", { $0.setLanguage(.en); $0.reload() }, nil),
            ("search-en", { $0.reload(); $0.query = "chart" }, nil),
            ("detail-en", { $0.reload(); _ = $0.handle(.right) }, nil),
        ]
        for (name, configure, change) in states {
            for (scheme, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
                configure(model)
                let view = PopoverView(model: model, hotKeyLabel: AppDelegate.hotKeyLabel)
                    .background(Color(nsColor: .windowBackgroundColor))
                let host = NSHostingView(rootView: view)
                host.appearance = NSAppearance(named: appearance)
                // A real window lets the scroll view lay out and scroll as it does on screen.
                let window = NSWindow(contentRect: NSRect(origin: .zero, size: host.fittingSize),
                                      styleMask: .borderless, backing: .buffered, defer: false)
                window.contentView = host
                host.frame = NSRect(origin: .zero, size: host.fittingSize)
                // Ordered in but far off screen, so SwiftUI's display cycle runs.
                window.setFrameOrigin(NSPoint(x: -10_000, y: -10_000))
                window.orderFrontRegardless()
                settle()
                if let change {
                    change(model)
                    settle()
                }
                host.layoutSubtreeIfNeeded()
                guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { continue }
                host.cacheDisplay(in: host.bounds, to: bitmap)
                let file = directory.appendingPathComponent("\(name)-\(scheme).png")
                try? bitmap.representation(using: .png, properties: [:])?.write(to: file)
                print(file.path)
                window.orderOut(nil)
                window.contentView = nil
            }
        }
    }

    /// Runs the main run loop briefly so SwiftUI updates, scrolls and finishes animations.
    private static func settle() {
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
    }
}
