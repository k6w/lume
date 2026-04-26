import SwiftUI

/// First-run flow. Seven cards: Welcome, Capture, Find, Tags, Snippets,
/// Hot Key, Done. Each card pairs prose with a small concrete demo so
/// the user understands what Lume actually does, not just that it has
/// a feature list.
@MainActor
struct OnboardingWindow: View {
    @LumeAccent private var accent
    let environment: AppEnvironment
    var onFinish: () -> Void
    @State private var step: Int = 0
    @State private var hotKey: HotKeyChord? = HotKeyService.loadStoredChord() ?? .default

    private let stepCount = 7

    var body: some View {
        ZStack {
            background
            VStack(spacing: 0) {
                content
                    .frame(maxHeight: .infinity)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal:   .move(edge: .leading).combined(with: .opacity)
                    ))
                indicator
                    .padding(.bottom, 6)
                buttonBar
            }
            .padding(Tokens.Spacing.xl)
        }
        .frame(width: 620, height: 640)
    }

    private var background: some View {
        ZStack {
            Tokens.Brand.ink
            RadialGradient(
                colors: [accent.opacity(0.32), accent.opacity(0.06), .clear],
                center: .top, startRadius: 0, endRadius: 580
            )
        }
        .ignoresSafeArea()
        .overlay(.ultraThinMaterial)
        .ignoresSafeArea()
    }

    @ViewBuilder private var content: some View {
        switch step {
        case 0: WelcomeStep()
        case 1: CaptureStep()
        case 2: FindStep()
        case 3: TagsStep()
        case 4: SnippetsStep()
        case 5: HotkeyOnboardingStep(chord: $hotKey, environment: environment)
        default: DoneStep()
        }
    }

    private var indicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<stepCount, id: \.self) { i in
                Capsule()
                    .fill(i == step ? accent : Color.secondary.opacity(0.3))
                    .frame(width: i == step ? 18 : 6, height: 6)
                    .animation(.easeInOut(duration: 0.18), value: step)
            }
        }
    }

    private var buttonBar: some View {
        HStack {
            if step > 0 {
                Button("Back") {
                    withAnimation(.easeInOut(duration: 0.22)) { step -= 1 }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            } else {
                Button("Skip") { onFinish() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(step < stepCount - 1 ? "Continue" : "Get started") {
                withAnimation(.easeInOut(duration: 0.22)) {
                    if step < stepCount - 1 {
                        step += 1
                    } else {
                        onFinish()
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.return)
        }
    }
}
