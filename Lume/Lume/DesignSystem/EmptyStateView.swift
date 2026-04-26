import SwiftUI

/// Reusable empty-state placeholder. One symbol, one title, one nudge.
struct EmptyStateView: View {
    var symbol: String
    var title: String
    var subtitle: String? = nil
    var actionLabel: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: Tokens.Spacing.s) {
            Spacer()
            Image(systemName: symbol)
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(LumeTheme.accent)
                .padding(.bottom, 4)
            Text(title)
                .font(.title3.weight(.medium))
            if let subtitle {
                Text(subtitle)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 320)
            }
            if let actionLabel, let action {
                Button(actionLabel, action: action)
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .padding(.top, 6)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Tokens.Spacing.l)
    }
}
