import SwiftUI

/// Minimal popover row: just the content on the left and the source app
/// icon on the right. Meta info (relative time, hit count, file warning)
/// and the pin button are hidden until hover, so the list reads very
/// dense at rest.
struct ClipRowMinimal: View {
    @LumeAccent private var accent
    let clip: Clip
    let isHighlighted: Bool
    var onPaste: () -> Void
    var onPin: () -> Void
    var onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: Tokens.Spacing.s) {
                preview
                Spacer(minLength: 8)
                trailingIcons
            }
            if isHovered || isHighlighted {
                meta
                    .padding(.top, 3)
                    .transition(.opacity)
            }
        }
        .padding(.vertical, isHovered || isHighlighted ? 6 : 5)
        .padding(.horizontal, Tokens.Spacing.m)
        .background {
            RoundedRectangle(cornerRadius: Tokens.Radius.m, style: .continuous)
                .fill(rowBackground)
        }
        .overlay {
            if isHighlighted {
                RoundedRectangle(cornerRadius: Tokens.Radius.m, style: .continuous)
                    .stroke(accent.opacity(0.5), lineWidth: 1)
            }
        }
        .contentShape(Rectangle())
        .onHover { h in
            withAnimation(.easeInOut(duration: 0.12)) { isHovered = h }
        }
        .onTapGesture { onPaste() }
        .contextMenu { contextMenu }
    }

    @ViewBuilder private var preview: some View {
        switch clip.kind {
        case .color:
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color(hex: clip.colorHex ?? "") ?? .gray)
                    .frame(width: 16, height: 16)
                    .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .stroke(.white.opacity(0.4), lineWidth: 0.5))
                Text(clip.colorHex ?? "—")
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
            }
        case .image:
            HStack(spacing: 8) {
                if let data = clip.thumbnailData ?? clip.imageData {
                    // Inline 18-px-tall thumb keeps the row dense but lets
                    // the eye recognise screenshots/photos at a glance —
                    // far more useful than a generic photo glyph.
                    ThumbView(
                        data: data,
                        contentMode: .fill,
                        maxWidth: 32, maxHeight: 18,
                        radius: 3
                    )
                    .frame(width: 32, height: 18)
                } else {
                    Image(systemName: "photo")
                        .foregroundStyle(accent)
                }
                Text("Image")
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
            }
        case .file:
            HStack(spacing: 8) {
                Image(systemName: "doc")
                    .foregroundStyle(accent)
                Text(clip.preview)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        default:
            Text(clip.preview)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    private var trailingIcons: some View {
        HStack(spacing: 6) {
            if clip.isEncrypted {
                Image(systemName: "lock.fill")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            if clip.kind == .file && !clip.allFilesExist {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
            // Pin (visible if pinned, OR on hover/selection)
            if clip.isPinned || isHovered || isHighlighted {
                Button(action: onPin) {
                    Image(systemName: clip.isPinned ? "pin.fill" : "pin")
                        .font(.caption)
                        .foregroundStyle(clip.isPinned ? accent : .secondary)
                        .rotationEffect(.degrees(45))
                }
                .buttonStyle(.plain)
                .help(clip.isPinned ? "Unpin" : "Pin")
            }
            // App icon, always visible
            AppIconView(bundleID: clip.sourceBundleID, size: 14)
        }
    }

    private var meta: some View {
        HStack(spacing: 6) {
            Text(clip.lastSeenAt, style: .relative)
            if clip.byteSize > 0 {
                Text("·").foregroundStyle(.tertiary)
                Text(ByteCountFormatter.string(
                    fromByteCount: Int64(clip.byteSize), countStyle: .file
                ))
                .monospacedDigit()
            }
            if clip.hitCount > 1 {
                Text("·").foregroundStyle(.tertiary)
                Text("×\(clip.hitCount)").monospacedDigit()
            }
            if let bid = clip.sourceBundleID {
                Text("·").foregroundStyle(.tertiary)
                Text(bid.split(separator: ".").last.map(String.init) ?? bid)
                    .lineLimit(1)
            }
            Spacer()
        }
        .font(.caption2)
        .foregroundStyle(.tertiary)
    }

    private var rowBackground: Color {
        if isHighlighted { return accent.opacity(0.18) }
        if isHovered     { return Color.primary.opacity(0.05) }
        return .clear
    }

    @ViewBuilder private var contextMenu: some View {
        Button("Paste",                          action: onPaste).keyboardShortcut(.return)
        Button(clip.isPinned ? "Unpin" : "Pin",  action: onPin)
        Divider()
        Button(role: .destructive, action: onDelete) { Text("Delete") }
    }
}
