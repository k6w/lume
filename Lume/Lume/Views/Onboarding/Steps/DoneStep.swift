import SwiftUI

struct DoneStep: View {
    @LumeAccent private var accent

    var body: some View {
        VStack(spacing: Tokens.Spacing.l) {
            Spacer(minLength: 0)
            Image(systemName: "sparkles")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(accent)
                .shadow(color: accent.opacity(0.4), radius: 30, y: 8)
            Text("You're set.")
                .font(.system(size: 32, weight: .semibold))
                .tracking(-0.5)

            VStack(spacing: 6) {
                Text("Look up there ↑")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text("Click the Lume glyph in your menu bar to see your history.\nRight-click for **Open Lume…** and **Settings…**.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Tokens.Spacing.l)

            Spacer(minLength: 0)

            VStack(spacing: 4) {
                Text("Next: copy something. It'll appear instantly.")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                Text("Storage stays under \(retentionLabel) days unless you pin it.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var retentionLabel: String {
        let days = UserDefaults.standard.integer(forKey: CaptureSettings.Key.retentionText.rawValue)
        return "\(days == 0 ? 30 : days)"
    }
}
