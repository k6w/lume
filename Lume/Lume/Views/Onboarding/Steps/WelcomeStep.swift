import SwiftUI

struct WelcomeStep: View {
    @Environment(LumeTheme.self) private var theme
    var body: some View {
        VStack(spacing: Tokens.Spacing.l) {
            Spacer()
            Image("LogoGlyph")
                .resizable()
                .interpolation(.high)
                .frame(width: 96, height: 96)
                .foregroundStyle(theme.accent)
            VStack(spacing: 6) {
                Text("Lume")
                    .font(.system(size: 36, weight: .semibold))
                    .tracking(-1)
                Text("A clipboard, lit.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            Text("Lume keeps everything you copy in a fast, searchable history that lives in your menu bar and syncs across your Macs through your iCloud account.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, Tokens.Spacing.l)
            Spacer()
        }
    }
}
