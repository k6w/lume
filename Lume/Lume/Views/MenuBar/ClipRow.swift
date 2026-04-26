import SwiftUI

/// One row in the history list. Single-tap activates (paste). Compact
/// chrome so 7+ rows fit in the popover.
struct ClipRow: View {
    @LumeAccent private var accent
    let clip: Clip
    let isHighlighted: Bool
    var onPaste: () -> Void
    var onPin: () -> Void
    var onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .top, spacing: Tokens.Spacing.m) {
            kindChip
            VStack(alignment: .leading, spacing: 3) {
                ClipPreview(clip: clip, compact: true)
                metaRow
            }
            Spacer(minLength: 0)
            trailingControls
                .opacity(isHovered || isHighlighted || clip.isPinned ? 1 : 0)
                .animation(.easeInOut(duration: 0.12), value: isHovered)
        }
        .padding(.vertical, Tokens.Spacing.s)
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
        .onHover { isHovered = $0 }
        .onTapGesture { onPaste() }
        .contextMenu { contextMenu }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(clip.kind.displayName) — \(clip.preview)"))
        .accessibilityAddTraits(isHighlighted ? .isSelected : [])
    }

    private var rowBackground: Color {
        if isHighlighted { return accent.opacity(0.18) }
        if isHovered     { return Color.primary.opacity(0.05) }
        return .clear
    }

    private var kindChip: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(accent.opacity(0.16))
            Image(systemName: clip.kind.sfSymbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(accent)
        }
        .frame(width: 26, height: 26)
    }

    private var metaRow: some View {
        HStack(spacing: 6) {
            if let bid = clip.sourceBundleID {
                AppIconView(bundleID: bid, size: 12)
                Text(appName(from: bid))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Text(clip.lastSeenAt, style: .relative)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            if clip.hitCount > 1 {
                Text("×\(clip.hitCount)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
            if clip.isEncrypted {
                Image(systemName: "lock.fill")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            if clip.kind == .file && !clip.allFilesExist {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .help("Some files have moved or been deleted")
            }
        }
    }

    private var trailingControls: some View {
        HStack(spacing: 4) {
            Button(action: onPin) {
                Image(systemName: clip.isPinned ? "pin.fill" : "pin")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(clip.isPinned ? accent : .secondary)
                    .rotationEffect(.degrees(45))
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(clip.isPinned ? "Unpin" : "Pin")
        }
    }

    @ViewBuilder private var contextMenu: some View {
        Button("Paste",                 action: onPaste).keyboardShortcut(.return)
        Button(clip.isPinned ? "Unpin" : "Pin", action: onPin)
        Divider()
        Button(role: .destructive, action: onDelete) { Text("Delete") }
    }

    /// Pulls a friendly app name out of a bundle id. `com.apple.dt.Xcode` → `Xcode`.
    private func appName(from bundleID: String) -> String {
        if let last = bundleID.split(separator: ".").last { return String(last) }
        return bundleID
    }
}
