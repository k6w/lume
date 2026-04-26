import SwiftUI

/// Type-aware preview cell. Routes the visual based on `Clip.kind` so
/// the popover row, the detail pane, and the snippet cell can all share
/// one renderer.
struct ClipPreview: View {
    let clip: Clip
    var compact: Bool = false

    var body: some View {
        switch clip.kind {
        case .image: imagePreview
        case .color: colorPreview
        case .file:  filePreview
        case .code:  codePreview
        case .rtf, .html, .text: textPreview
        }
    }

    @ViewBuilder private var textPreview: some View {
        Text(clip.preview)
            .font(compact ? .system(size: 13) : .body)
            .lineLimit(compact ? 2 : 8)
            .foregroundStyle(.primary)
            .multilineTextAlignment(.leading)
    }

    @ViewBuilder private var codePreview: some View {
        Text(clip.preview)
            .font(.system(size: compact ? 12 : 13, design: .monospaced))
            .lineLimit(compact ? 2 : 12)
    }

    @ViewBuilder private var imagePreview: some View {
        if let data = clip.thumbnailData ?? clip.imageData {
            ThumbView(
                data: data,
                contentMode: .fill,
                maxWidth: compact ? 56 : .infinity,
                maxHeight: compact ? 56 : 220
            )
        } else {
            placeholder("photo")
        }
    }

    @ViewBuilder private var colorPreview: some View {
        let color = Color(hex: clip.colorHex ?? "") ?? .gray
        HStack(spacing: Tokens.Spacing.s) {
            RoundedRectangle(cornerRadius: Tokens.Radius.s, style: .continuous)
                .fill(color)
                .frame(width: compact ? 24 : 36, height: compact ? 24 : 36)
                .overlay {
                    RoundedRectangle(cornerRadius: Tokens.Radius.s, style: .continuous)
                        .stroke(.white.opacity(0.4), lineWidth: 0.5)
                }
            Text(clip.colorHex ?? "—")
                .font(.system(.body, design: .monospaced))
        }
    }

    @ViewBuilder private var filePreview: some View {
        let names = (clip.fileURLs ?? "")
            .split(separator: "\n")
            .map { ($0 as Substring).split(separator: "/").last.map(String.init) ?? String($0) }
        VStack(alignment: .leading, spacing: 2) {
            ForEach(names.prefix(compact ? 1 : 4), id: \.self) { name in
                HStack(spacing: 6) {
                    Image(systemName: "doc")
                    Text(name).lineLimit(1).truncationMode(.middle)
                }.font(.system(size: compact ? 12 : 13))
            }
            if names.count > (compact ? 1 : 4) {
                Text("+\(names.count - (compact ? 1 : 4)) more")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func placeholder(_ symbol: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
            Text(clip.kind.displayName).foregroundStyle(.secondary)
        }
    }
}
