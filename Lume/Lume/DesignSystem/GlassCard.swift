import SwiftUI

/// A reusable rounded container that picks up Liquid Glass on macOS 26.
/// We isolate the modifier here so future SDKs can ship behind one
/// updateable surface.
struct GlassCard<Content: View>: View {
    var radius: CGFloat = Tokens.Radius.l
    var padding: CGFloat = Tokens.Spacing.m
    var tint: Color? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background {
                if let tint {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(tint.opacity(0.12))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .glassEffect(in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

/// Use at the root of any glass-heavy surface so multiple glass layers
/// share a single backdrop sample (Apple's perf guidance).
struct GlassRoot<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        GlassEffectContainer { content() }
    }
}
