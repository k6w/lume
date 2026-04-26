import SwiftUI

/// Glass card all onboarding steps render their demo inside. Keeps the
/// visual language consistent across steps and provides a soft drop
/// shadow + accent border so the demo block reads as a tangible thing.
struct OnboardingCard<Content: View>: View {
    @LumeAccent private var accent
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(Tokens.Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial,
                        in: RoundedRectangle(cornerRadius: Tokens.Radius.l, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.l, style: .continuous)
                    .stroke(accent.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: accent.opacity(0.18), radius: 18, y: 8)
    }
}

/// Reusable header pair for onboarding steps: eyebrow / title / lede.
struct OnboardingHeader: View {
    @LumeAccent private var accent
    var eyebrow: String
    var title: String
    var lede: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(eyebrow.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(1.2)
                .foregroundStyle(accent)
            Text(title)
                .font(.system(size: 30, weight: .semibold))
                .tracking(-0.6)
            Text(lede)
                .font(.title3)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
