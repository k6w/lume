import SwiftUI

/// Configurable global hotkeys. Currently exposes the popover hotkey;
/// future shortcuts (e.g. paste-as-plain, snippet inserts) will land here.
struct HotkeysPane: View {
    let environment: AppEnvironment
    @State private var current: HotKeyChord? = HotKeyService.loadStoredChord() ?? .default

    var body: some View {
        Form {
            Section("Show clipboard") {
                LabeledContent("Shortcut") {
                    HotKeyRecorder(chord: Binding(
                        get: { current },
                        set: { new in
                            // Clearing falls back to the default so there's
                            // always *something* registered.
                            current = new ?? .default
                            environment.hotKey.update(current ?? .default)
                        }
                    ))
                }
                Button("Reset to ⌥⌘V") {
                    current = .default
                    environment.hotKey.resetToDefault()
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                Text("Click the recorder, then press the chord. The shortcut is registered globally — it works from any app.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
