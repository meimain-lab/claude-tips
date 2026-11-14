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
        let model = TipsViewModel(locations: .standard(home: home, bundledTips: bundled))
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let states: [(String, (TipsViewModel) -> Void)] = [
            ("list", { $0.reload() }),
            ("slash", { $0.reload(); _ = $0.handle(.segment(2)); _ = $0.handle(.down) }),
            ("search", { $0.reload(); $0.query = "图" }),
            ("no-results", { $0.reload(); $0.query = "zzzz" }),
            ("detail", { $0.reload(); _ = $0.handle(.right) }),
        ]
        for (name, configure) in states {
            for (scheme, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
                configure(model)
                let view = PopoverView(model: model, hotKeyLabel: AppDelegate.hotKeyLabel)
                    .background(Color(nsColor: .windowBackgroundColor))
                let host = NSHostingView(rootView: view)
                host.appearance = NSAppearance(named: appearance)
                host.frame = NSRect(origin: .zero, size: host.fittingSize)
                host.layoutSubtreeIfNeeded()
                guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { continue }
                host.cacheDisplay(in: host.bounds, to: bitmap)
                let file = directory.appendingPathComponent("\(name)-\(scheme).png")
                try? bitmap.representation(using: .png, properties: [:])?.write(to: file)
                print(file.path)
            }
        }
    }
}
