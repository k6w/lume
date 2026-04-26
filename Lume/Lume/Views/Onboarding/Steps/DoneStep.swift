import SwiftUI

struct DoneStep: View {
    var body: some View {
        VStack(spacing: Tokens.Spacing.l) {
            Spacer(minLength: 0)
            Image(systemName: "sparkles")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(LumeTheme.accent)
            Text("You're set.")
                .font(.system(size: 32, weight: .semibold))
            VStack(spacing: 6) {
                Text("Look up there ↑")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text("Click the Lume glyph in your menu bar to see your history. Double-click to open the full app.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, Tokens.Spacing.l)
            Spacer(minLength: 0)
            Text("Try copying something now — it'll appear instantly.")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
    }
}
