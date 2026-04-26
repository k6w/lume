import SwiftUI
import AppKit
import Carbon.HIToolbox

/// "Click to record" pill. Tapping arms an `NSEvent` local monitor that
/// captures the next key press. Modifiers are required (no bare letters)
/// so the recorded chord is something the system will actually deliver
/// as a global shortcut.
struct HotKeyRecorder: View {
    @Binding var chord: HotKeyChord?
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        Button {
            toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: recording ? "circle.fill" : "keyboard")
                    .font(.caption)
                    .foregroundStyle(recording ? Color.red : Color.secondary)
                Text(label)
                    .font(.system(.body, design: .monospaced))
                Spacer(minLength: 8)
                if !recording, chord != nil {
                    Button {
                        chord = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .help("Clear shortcut")
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(recording ? Color.red.opacity(0.10) : Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(recording ? Color.red.opacity(0.4) : Color.primary.opacity(0.15),
                            lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: 220)
        .onDisappear { stop() }
    }

    private var label: String {
        if recording { return "Press shortcut…  (esc cancels)" }
        return chord?.displayString ?? "Click to record"
    }

    private func toggle() {
        if recording { stop() } else { start() }
    }

    private func start() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            // Esc cancels.
            if event.keyCode == UInt16(kVK_Escape) {
                stop()
                return nil
            }
            // Need at least one modifier or the chord won't survive as a
            // global hot-key (system would steal raw letters).
            let mods = event.modifierFlags.intersection([.command, .option, .control, .shift])
            guard !mods.isEmpty else { return nil }
            let key = HotKeyChord.keyName(forKeyCode: event.keyCode)
            guard let key else { return nil }

            let recorded = HotKeyChord(
                keyCode: UInt32(event.keyCode),
                modifiers: HotKeyChord.carbonModifiers(from: mods),
                keyName: key
            )
            chord = recorded
            stop()
            return nil
        }
    }

    private func stop() {
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
        recording = false
    }
}

/// Persistable representation of a recorded hot-key chord.
struct HotKeyChord: Codable, Hashable, Sendable {
    var keyCode: UInt32
    /// Carbon modifier mask — what `RegisterEventHotKey` expects.
    var modifiers: UInt32
    /// Human-readable key name (e.g. "V", "Space"). Used for the label.
    var keyName: String

    var displayString: String {
        var parts: [String] = []
        if modifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if modifiers & UInt32(optionKey)  != 0 { parts.append("⌥") }
        if modifiers & UInt32(shiftKey)   != 0 { parts.append("⇧") }
        if modifiers & UInt32(cmdKey)     != 0 { parts.append("⌘") }
        return (parts + [keyName]).joined()
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var m: Int = 0
        if flags.contains(.command) { m |= cmdKey }
        if flags.contains(.option)  { m |= optionKey }
        if flags.contains(.control) { m |= controlKey }
        if flags.contains(.shift)   { m |= shiftKey }
        return UInt32(m)
    }

    static func keyName(forKeyCode keyCode: UInt16) -> String? {
        // Hand-mapped table covering letters, digits, common punctuation,
        // and a handful of named keys. Sticking to ANSI keyCodes makes
        // the persisted JSON layout-agnostic.
        let table: [Int: String] = [
            kVK_ANSI_A: "A", kVK_ANSI_B: "B", kVK_ANSI_C: "C", kVK_ANSI_D: "D",
            kVK_ANSI_E: "E", kVK_ANSI_F: "F", kVK_ANSI_G: "G", kVK_ANSI_H: "H",
            kVK_ANSI_I: "I", kVK_ANSI_J: "J", kVK_ANSI_K: "K", kVK_ANSI_L: "L",
            kVK_ANSI_M: "M", kVK_ANSI_N: "N", kVK_ANSI_O: "O", kVK_ANSI_P: "P",
            kVK_ANSI_Q: "Q", kVK_ANSI_R: "R", kVK_ANSI_S: "S", kVK_ANSI_T: "T",
            kVK_ANSI_U: "U", kVK_ANSI_V: "V", kVK_ANSI_W: "W", kVK_ANSI_X: "X",
            kVK_ANSI_Y: "Y", kVK_ANSI_Z: "Z",
            kVK_ANSI_0: "0", kVK_ANSI_1: "1", kVK_ANSI_2: "2", kVK_ANSI_3: "3",
            kVK_ANSI_4: "4", kVK_ANSI_5: "5", kVK_ANSI_6: "6", kVK_ANSI_7: "7",
            kVK_ANSI_8: "8", kVK_ANSI_9: "9",
            kVK_Space:    "Space",
            kVK_Return:   "↩",
            kVK_Tab:      "⇥",
            kVK_Escape:   "⎋",
            kVK_ANSI_Minus:        "-",
            kVK_ANSI_Equal:        "=",
            kVK_ANSI_LeftBracket:  "[",
            kVK_ANSI_RightBracket: "]",
            kVK_ANSI_Backslash:    "\\",
            kVK_ANSI_Semicolon:    ";",
            kVK_ANSI_Quote:        "'",
            kVK_ANSI_Comma:        ",",
            kVK_ANSI_Period:       ".",
            kVK_ANSI_Slash:        "/"
        ]
        return table[Int(keyCode)]
    }

    static let `default` = HotKeyChord(
        keyCode: UInt32(kVK_ANSI_V),
        modifiers: UInt32(optionKey | cmdKey),
        keyName: "V"
    )
}
