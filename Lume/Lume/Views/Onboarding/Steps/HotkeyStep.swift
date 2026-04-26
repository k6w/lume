import SwiftUI

struct HotkeyStep: View {
    let environment: AppEnvironment

    var body: some View {
        VStack(spacing: Tokens.Spacing.l) {
            Spacer(minLength: 0)
            Text("Pop it open from anywhere")
                .font(.system(size: 28, weight: .semibold))
                .multilineTextAlignment(.center)
            HStack(spacing: 6) {
                key("⌥")
                key("⌘")
                key("V")
            }
            Text("That's the default. You can change it later in Settings → Hot Keys.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, Tokens.Spacing.l)
            Spacer(minLength: 0)
        }
    }

    private func key(_ s: String) -> some View {
        Text(s)
            .font(.system(size: 28, weight: .semibold))
            .frame(width: 64, height: 64)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(LumeTheme.accent.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(LumeTheme.accent.opacity(0.45), lineWidth: 1)
            )
    }
}
