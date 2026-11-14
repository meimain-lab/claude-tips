import AppKit
import Carbon.HIToolbox

/// A system-wide hot key through Carbon's RegisterEventHotKey.
/// Needs no Accessibility permission, unlike a global NSEvent monitor.
@MainActor
final class HotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let action: () -> Void

    /// Registers the key; `register()` reports whether the system accepted it.
    init(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) {
        self.action = action
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    private let keyCode: UInt32
    private let modifiers: UInt32

    /// Returns false when another app already holds the same combination.
    @discardableResult
    func register() -> Bool {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return noErr }
                let hotKey = Unmanaged<HotKey>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async { hotKey.action() }
                return noErr
            },
            1, &eventType, context, &handlerRef
        )
        guard installStatus == noErr else { return false }
        let hotKeyID = EventHotKeyID(signature: OSType(0x5449_5053), id: 1) // "TIPS"
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        return status == noErr
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
        hotKeyRef = nil
        handlerRef = nil
    }

    /// ⌥⌘K, the default.
    static func optionCommandK(action: @escaping () -> Void) -> HotKey {
        HotKey(keyCode: UInt32(kVK_ANSI_K), modifiers: UInt32(optionKey | cmdKey), action: action)
    }
}
