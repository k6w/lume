import AppKit
import Carbon.HIToolbox

/// Thin Swift wrapper around `RegisterEventHotKey`. Sandbox-OK. Accepts a
/// `HotKeyChord` (loaded from UserDefaults or supplied as a default) and
/// routes the press through a closure on the main actor.
@MainActor
final class HotKeyService {
    static let storageKey = "lume.hotkey.popover"

    private var hotKeyRef: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var current: HotKeyChord?
    private var callback: (() -> Void)?

    /// Boot the service. Reads the persisted chord (or uses default) and
    /// installs the handler. Call once at app start.
    func start(_ handler: @escaping () -> Void) {
        self.callback = handler
        installEventHandler()
        register(persistedOrDefault())
    }

    /// Replace the active chord at runtime — called from Settings →
    /// Hot Keys when the user records a new shortcut.
    func update(_ chord: HotKeyChord) {
        unregister()
        register(chord)
        persist(chord)
    }

    func resetToDefault() {
        update(HotKeyChord.default)
    }

    func unregisterAll() {
        unregister()
        if let h = handler {
            RemoveEventHandler(h)
            self.handler = nil
        }
        callback = nil
    }

    // MARK: persistence

    static func loadStoredChord() -> HotKeyChord? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(HotKeyChord.self, from: data)
    }

    private func persist(_ chord: HotKeyChord) {
        if let data = try? JSONEncoder().encode(chord) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    private func persistedOrDefault() -> HotKeyChord {
        Self.loadStoredChord() ?? .default
    }

    // MARK: registration

    private func register(_ chord: HotKeyChord) {
        var ref: EventHotKeyRef?
        let id = EventHotKeyID(signature: OSType(0x4C554D45 /* "LUME" */), id: 1)
        let status = RegisterEventHotKey(chord.keyCode, chord.modifiers, id,
                                         GetApplicationEventTarget(), 0, &ref)
        if status == noErr {
            self.hotKeyRef = ref
            self.current = chord
        } else {
            NSLog("[Lume] hot-key registration failed: \(status)")
        }
    }

    private func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        current = nil
    }

    private func installEventHandler() {
        guard handler == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        let opaque = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return noErr }
            let me = Unmanaged<HotKeyService>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async { me.callback?() }
            return noErr
        }, 1, &spec, opaque, &handler)
    }
}
