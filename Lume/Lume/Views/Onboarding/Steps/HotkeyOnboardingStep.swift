import SwiftUI

/// Records the global popover hotkey live during onboarding. Wires
/// straight into HotKeyService so what the user picks here is what
/// they get from the moment they finish the flow.
struct HotkeyOnboardingStep: View {
    @LumeAccent private var accent
    @Binding var chord: HotKeyChord?
    let environment: AppEnvironment

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.l) {
            OnboardingHeader(
                eyebrow: "05 · Hot key",
                title: "Pop it open from anywhere.",
                lede: "Pick a global shortcut. The default is ⌥⌘V — change it now or later in Settings → Hot Keys."
            )
            OnboardingCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        Image(systemName: "keyboard")
                            .font(.system(size: 22))
                            .foregroundStyle(accent)
                            .frame(width: 36, height: 36)
                            .background(RoundedRectangle(cornerRadius: 8).fill(accent.opacity(0.16)))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Show clipboard")
                                .font(.headline)
                            Text("Click the recorder, then press the shortcut you want.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    HStack {
                        HotKeyRecorder(chord: Binding(
                            get: { chord },
                            set: { new in
                                let resolved = new ?? .default
                                chord = resolved
                                environment.hotKey.update(resolved)
                            }
                        ))
                        Spacer()
                        Button("Reset") {
                            chord = .default
                            environment.hotKey.resetToDefault()
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                    }
                }
            }
        }
        .padding(.horizontal, Tokens.Spacing.s)
    }
}
