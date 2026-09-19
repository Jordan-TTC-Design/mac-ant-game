import AppKit
import Carbon.HIToolbox

/// System-wide shortcuts (⌃⌥ plus a key). Registered with the system's hot-key service, so no permissions are needed.
final class HotKeys {
    static let shared = HotKeys()

    private var refs: [EventHotKeyRef] = []
    private var actions: [UInt32: () -> Void] = [:]
    private var handlerInstalled = false

    /// Registers `⌃⌥ key`; returns whether the system accepted it (another app may already use it).
    @discardableResult
    func register(keyCode: Int, action: @escaping () -> Void) -> Bool {
        installHandler()
        let id = UInt32(actions.count + 1)
        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x47424C4E), id: id) // 'GBLN'
        let status = RegisterEventHotKey(UInt32(keyCode), UInt32(controlKey | optionKey), hotKeyID, GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let ref else { return false }
        refs.append(ref)
        actions[id] = action
        return true
    }

    func unregisterAll() {
        refs.forEach { UnregisterEventHotKey($0) }
        refs = []
        actions = [:]
    }

    func press(_ id: UInt32) { actions[id]?() }

    private func installHandler() {
        guard !handlerInstalled else { return }
        handlerInstalled = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            DispatchQueue.main.async { HotKeys.shared.press(hotKeyID.id) }
            return noErr
        }, 1, &spec, nil, nil)
    }
}
