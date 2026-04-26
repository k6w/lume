import SwiftUI

/// Virtualized list of clips with arrow-key navigation and a pinned
/// section pinned to the top.
struct HistoryList: View {
    let clips: [Clip]
    @Binding var selection: String?
    var onPaste: (Clip) -> Void
    var onPin: (Clip) -> Void
    var onDelete: (Clip) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: Tokens.Spacing.xs) {
                    ForEach(clips, id: \.id) { clip in
                        ClipRow(
                            clip: clip,
                            isHighlighted: selection == clip.id,
                            onPaste: { onPaste(clip) },
                            onPin: { onPin(clip) },
                            onDelete: { onDelete(clip) }
                        )
                        .id(clip.id)
                        .onTapGesture { selection = clip.id }
                    }
                }
                .padding(.horizontal, Tokens.Spacing.s)
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
}
