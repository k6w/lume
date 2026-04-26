import SwiftUI

/// Virtualized list of clips with arrow-key navigation. Switches between
/// the two row styles based on `lume.popoverStyle` (Default / Minimal).
struct HistoryList: View {
    let clips: [Clip]
    @Binding var selection: String?
    var onPaste: (Clip) -> Void
    var onPin: (Clip) -> Void
    var onDelete: (Clip) -> Void

    @AppStorage(PopoverStyle.storageKey) private var styleRaw: String = PopoverStyle.default.rawValue
    private var style: PopoverStyle { PopoverStyle(rawValue: styleRaw) ?? .default }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: style == .minimal ? 1 : Tokens.Spacing.xs) {
                    ForEach(clips, id: \.id) { clip in
                        rowView(for: clip)
                            .id(clip.id)
                            .onTapGesture { selection = clip.id }
                    }
                }
                .padding(.horizontal, Tokens.Spacing.s)
                .padding(.top, 6)
                .padding(.bottom, Tokens.Spacing.s)
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
            .scrollEdgeEffectStyle(.soft, for: .bottom)
            .onChange(of: selection) { _, newValue in
                if let id = newValue {
                    withAnimation(.easeInOut(duration: Tokens.Duration.snap)) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func rowView(for clip: Clip) -> some View {
        switch style {
        case .default:
            ClipRow(
                clip: clip,
                isHighlighted: selection == clip.id,
                onPaste: { onPaste(clip) },
                onPin:   { onPin(clip) },
                onDelete: { onDelete(clip) }
            )
        case .minimal:
            ClipRowMinimal(
                clip: clip,
                isHighlighted: selection == clip.id,
                onPaste: { onPaste(clip) },
                onPin:   { onPin(clip) },
                onDelete: { onDelete(clip) }
            )
        }
    }
}
