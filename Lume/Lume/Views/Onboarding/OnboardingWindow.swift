import SwiftUI

/// First-run welcome flow. Four steps, dot indicator at the bottom,
/// glass background with the brand gradient bleeding through.
@MainActor
struct OnboardingWindow: View {
    let environment: AppEnvironment
    var onFinish: () -> Void
    @State private var step: Int = 0

    var body: some View {
        ZStack {
            background
            VStack(spacing: 0) {
                content
                    .frame(maxHeight: .infinity)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                indicator
                buttonBar
            }
            .padding(Tokens.Spacing.xl)
        }
        .frame(width: 540, height: 580)
    }

    private var background: some View {
        // Restrained: deep slate base + a single soft indigo glow.
        // Not a rainbow.
        ZStack {
            Tokens.Brand.ink
            RadialGradient(
                colors: [Tokens.Brand.indigo.opacity(0.28),
                         Tokens.Brand.indigo.opacity(0.05),
                         .clear],
                center: .top,
                startRadius: 0,
                endRadius: 520
            )
        }
        .ignoresSafeArea()
        .overlay(.ultraThinMaterial)
        .ignoresSafeArea()
    }

    @ViewBuilder private var content: some View {
        switch step {
        case 0: WelcomeStep()
        case 1: PermissionsStep()
        case 2: HotkeyStep(environment: environment)
        default: DoneStep()
        }
    }

    private var indicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<4) { i in
                Circle()
                    .fill(i == step ? LumeTheme.accent : Color.secondary.opacity(0.3))
                    .frame(width: 7, height: 7)
            }
        }
        .padding(.bottom, Tokens.Spacing.s)
    }

    private var buttonBar: some View {
        HStack {
            if step > 0 {
                Button("Back") { withAnimation(.easeInOut) { step -= 1 } }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(step < 3 ? "Continue" : "Get started") {
                withAnimation(.easeInOut) {
                    if step < 3 { step += 1 } else { onFinish() }
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.return)
        }
    }
}
