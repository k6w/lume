import SwiftUI

struct WelcomeStep: View {
    @LumeAccent private var accent

    var body: some View {
        VStack(spacing: Tokens.Spacing.l) {
            Spacer()
            Image("LogoGlyph")
                .resizable()
                .interpolation(.high)
                .frame(width: 96, height: 96)
                .foregroundStyle(accent)
                .shadow(color: accent.opacity(0.45), radius: 30, y: 12)
            VStack(spacing: 8) {
                Text("Welcome to Lume")
                    .font(.system(size: 36, weight: .semibold))
                    .tracking(-1)
                Text("A clipboard, lit.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            Text("Lume keeps everything you copy in a fast, searchable history that lives in your menu bar — and syncs across your Macs through your iCloud account when you turn it on.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, Tokens.Spacing.xl)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }
}
