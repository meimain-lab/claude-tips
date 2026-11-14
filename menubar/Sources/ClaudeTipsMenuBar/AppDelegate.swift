import AppKit
import SwiftUI
import TipsCore

/// AppKit shell: a status item that toggles a transient popover hosting SwiftUI.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var keyMonitor: Any?
    private lazy var model: TipsViewModel = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let bundled = Bundle.main.url(forResource: "tips", withExtension: "json")
        return TipsViewModel(locations: .standard(home: home, bundledTips: bundled))
    }()

    static let hotKeyLabel = "⌥⌘K"

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "lightbulb", accessibilityDescription: "速查")
            image?.isTemplate = true
            button.image = image
            button.action = #selector(statusItemClicked(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        model.onCopied = { [weak self] in self?.closePopover() }
        let host = NSHostingController(rootView: PopoverView(model: model, hotKeyLabel: Self.hotKeyLabel))
        host.sizingOptions = .preferredContentSize
        popover.contentViewController = host
        popover.behavior = .transient
        popover.animates = false
        popover.delegate = self

    }

    /// Left click toggles the popover; right click (or control-click) offers 退出.
    @objc func statusItemClicked(_ sender: Any?) {
        let event = NSApp.currentEvent
        let isSecondary = event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true
        guard isSecondary, let button = statusItem.button else {
            togglePopover(sender)
            return
        }
        closePopover()
        let menu = NSMenu()
        menu.addItem(withTitle: "退出 Claude Tips", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
    }

    @objc func togglePopover(_ sender: Any?) {
        if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    func showPopover() {
        guard let button = statusItem.button else { return }
        model.reload()
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        installKeyMonitor()
    }

    func closePopover() {
        if popover.isShown { popover.performClose(nil) }
    }

    func popoverDidClose(_ notification: Notification) {
        removeKeyMonitor()
        // Hand focus back to the app the person was using.
        NSApp.hide(nil)
    }

    // MARK: Keys

    private func installKeyMonitor() {
        removeKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.popover.isShown else { return event }
            return self.handleKey(event) ? nil : event
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }

    /// Returns true when the popover handled the key and it should not reach the text field.
    private func handleKey(_ event: NSEvent) -> Bool {
        let editor = popover.contentViewController?.view.window?.firstResponder as? NSTextView
        // Keys belong to the input method while it is composing (pinyin and the like).
        if editor?.hasMarkedText() == true { return false }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var command: KeyCommand?
        if flags == .command, event.charactersIgnoringModifiers == "q" {
            NSApp.terminate(nil)
            return true
        } else if flags == .command, let digit = Int(event.charactersIgnoringModifiers ?? ""), (1...4).contains(digit) {
            command = .segment(digit)
        } else if flags.subtracting([.numericPad, .function]).isEmpty {
            switch event.keyCode {
            case 126: command = .up
            case 125: command = .down
            case 36, 76: command = .enter
            case 53: command = .escape
            case 123: command = .left
            case 124:
                // Leave → to the search field while the caret is not at the end of the text.
                if let editor, editor.selectedRange().location < (editor.string as NSString).length {
                    command = nil
                } else {
                    command = .right
                }
            default: command = nil
            }
        }
        guard let command else { return false }
        switch model.handle(command) {
        case .ignored: return false
        case .handled: return true
        case .close:
            closePopover()
            return true
        }
    }
}
