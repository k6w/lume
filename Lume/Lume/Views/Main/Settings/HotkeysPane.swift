import SwiftUI

struct HotkeysPane: View {
    let environment: AppEnvironment
    @AppStorage("lume.hotkey") private var stored: String = "opt-cmd-v"

    var body: some View {
        Form {
            Section("Show clipboard") {
                HStack {
                    Text("Hotkey")
                    Spacer()
                    Text(displayLabel(stored))
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 6).stroke(.separator))
                }
                Text("Default ⌥⌘V. Customizing the hotkey will land in v0.2.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func displayLabel(_ s: String) -> String {
        switch s {
        case "opt-cmd-v":  return "⌥⌘V"
        case "ctrl-cmd-v": return "⌃⌘V"
        default:           return s
        }
    }
}
