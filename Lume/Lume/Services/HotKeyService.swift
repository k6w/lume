import AppKit
import Carbon.HIToolbox

/// Thin Swift wrapper around `RegisterEventHotKey`. Sandbox-OK. Accepts a
/// chord like ⌥⌘V (default) and routes the press through a closure on the
/// main actor.
@MainActor
final class HotKeyService {
    struct Chord: Equatable, Sendable {
        var key: String     // single character
        var modifiers: UInt32

        static func optionCommand(_ key: String) -> Chord {
            Chord(key: key, modifiers: UInt32(optionKey | cmdKey))
        }
        static func controlCommand(_ key: String) -> Chord {
            Chord(key: key, modifiers: UInt32(controlKey | cmdKey))
        }
    }

    private var hotKeyRef: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var current: Chord?
    private var callback: (() -> Void)?

    func register(default chord: Chord, _ handler: @escaping () -> Void) {
        unregisterAll()
        self.callback = handler
        self.current = chord
        installEventHandler()

        var ref: EventHotKeyRef?
        let id = EventHotKeyID(signature: OSType(0x4C554D45 /* "LUME" */), id: 1)
        let keyCode = Self.virtualKeyCode(for: chord.key) ?? UInt32(kVK_ANSI_V)
        let status = RegisterEventHotKey(keyCode, chord.modifiers, id, GetApplicationEventTarget(), 0, &ref)
        if status == noErr {
            self.hotKeyRef = ref
        } else {
            NSLog("[Lume] hot-key registration failed: \(status)")
        }
    }

    func unregisterAll() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let h = handler {
            RemoveEventHandler(h)
            self.handler = nil
        }
        callback = nil
    }

    private func installEventHandler() {
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

    /// Map a one-character key to its virtual key code. Covers letters and
    /// the few punctuation keys most users reach for.
    private static func virtualKeyCode(for key: String) -> UInt32? {
        let lower = key.lowercased()
        let table: [String: Int] = [
            "a": kVK_ANSI_A, "b": kVK_ANSI_B, "c": kVK_ANSI_C, "d": kVK_ANSI_D,
            "e": kVK_ANSI_E, "f": kVK_ANSI_F, "g": kVK_ANSI_G, "h": kVK_ANSI_H,
            "i": kVK_ANSI_I, "j": kVK_ANSI_J, "k": kVK_ANSI_K, "l": kVK_ANSI_L,
            "m": kVK_ANSI_M, "n": kVK_ANSI_N, "o": kVK_ANSI_O, "p": kVK_ANSI_P,
            "q": kVK_ANSI_Q, "r": kVK_ANSI_R, "s": kVK_ANSI_S, "t": kVK_ANSI_T,
            "u": kVK_ANSI_U, "v": kVK_ANSI_V, "w": kVK_ANSI_W, "x": kVK_ANSI_X,
            "y": kVK_ANSI_Y, "z": kVK_ANSI_Z,
            "0": kVK_ANSI_0, "1": kVK_ANSI_1, "2": kVK_ANSI_2, "3": kVK_ANSI_3,
            "4": kVK_ANSI_4, "5": kVK_ANSI_5, "6": kVK_ANSI_6, "7": kVK_ANSI_7,
            "8": kVK_ANSI_8, "9": kVK_ANSI_9,
            ",": kVK_ANSI_Comma, ".": kVK_ANSI_Period, "/": kVK_ANSI_Slash,
            ";": kVK_ANSI_Semicolon, "'": kVK_ANSI_Quote,
            "[": kVK_ANSI_LeftBracket, "]": kVK_ANSI_RightBracket,
            "\\": kVK_ANSI_Backslash, "-": kVK_ANSI_Minus, "=": kVK_ANSI_Equal,
            " ": kVK_Space
        ]
        return table[lower].map(UInt32.init)
    }
}
