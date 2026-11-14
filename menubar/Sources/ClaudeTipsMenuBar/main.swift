import AppKit

MainActor.assumeIsolated {
    let arguments = CommandLine.arguments
    if let flag = arguments.firstIndex(of: "--snapshot"), arguments.indices.contains(flag + 1) {
        Snapshot.run(into: URL(fileURLWithPath: arguments[flag + 1]))
        exit(0)
    }
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
