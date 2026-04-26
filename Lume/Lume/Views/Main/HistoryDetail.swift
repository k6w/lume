import SwiftUI
import AppKit

/// Detail pane for a single clip: header with quick actions, body
/// preview, optional file-staleness banner, optional URL action,
/// quick-transform palette, text stats, and metadata.
struct HistoryDetail: View {
    let clip: Clip?
    let environment: AppEnvironment

    @State private var isEditing = false
    @State private var editBuffer = ""

    var body: some View {
        if let clip {
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Spacing.l) {
                    header(clip)
                    if clip.kind == .file && !clip.allFilesExist {
                        staleFileBanner
                    }
                    bodyCard(clip)
                    if let plain = clip.plainText, !plain.isEmpty {
                        smartActions(plain, clip: clip)
                        transforms(plain)
                        textStats(plain)
                    }
                    metadata(clip)
                    tagsRow(clip)
                }
                .padding(Tokens.Spacing.l)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("")
        } else {
            VStack(spacing: 12) {
                Spacer()
                Image(systemName: "rectangle.dashed")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(.secondary)
                Text("Pick a clip").font(.title3)
                Text("Select something on the left to see it here.")
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: header

    private func header(_ clip: Clip) -> some View {
        HStack(spacing: Tokens.Spacing.s) {
            Image(systemName: clip.kind.sfSymbol)
                .foregroundStyle(LumeTheme.accent)
            Text(clip.kind.displayName).font(.headline)
            Spacer()
            Button {
                environment.pasteInjector.copy(clip)
            } label: { Label("Copy", systemImage: "doc.on.doc") }
                .help("Copy back to the pasteboard")
            Button {
                try? environment.clipRepository.setPinned(!clip.isPinned, id: clip.id)
            } label: {
                Label(clip.isPinned ? "Unpin" : "Pin",
                      systemImage: clip.isPinned ? "pin.slash" : "pin")
            }
            Button(role: .destructive) {
                try? environment.clipRepository.delete(id: clip.id)
            } label: { Label("Delete", systemImage: "trash") }
        }
    }

    private var staleFileBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text("Some of these files have moved or been deleted.")
                .font(.callout)
            Spacer()
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(.orange.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    // MARK: body

    private func bodyCard(_ clip: Clip) -> some View {
        Group {
            if isEditing, let _ = clip.plainText {
                TextEditor(text: $editBuffer)
                    .font(.body)
                    .frame(minHeight: 240)
                    .padding(8)
                    .background(.regularMaterial,
                                in: RoundedRectangle(cornerRadius: Tokens.Radius.l, style: .continuous))
                HStack {
                    Button("Cancel") { isEditing = false }
                    Spacer()
                    Button("Save & Copy") { saveEdit(clip) }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.return)
                }
            } else {
                ZStack(alignment: .topTrailing) {
                    GlassCard(radius: Tokens.Radius.l) {
                        ClipPreview(clip: clip, compact: false)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if clip.plainText != nil {
                        Button {
                            editBuffer = clip.plainText ?? ""
                            isEditing = true
                        } label: {
                            Image(systemName: "pencil").padding(8)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .help("Edit before copying")
                        .padding(6)
                    }
                }
            }
        }
    }

    private func saveEdit(_ clip: Clip) {
        var copy = clip
        copy.plainText = editBuffer
        copy.byteSize = editBuffer.utf8.count
        // Persist as a new clip (don't mutate history) and copy it.
        let newClip = Clip.text(editBuffer, sourceBundleID: clip.sourceBundleID)
        try? environment.clipRepository.upsert(newClip)
        environment.pasteInjector.copy(newClip)
        isEditing = false
    }

    // MARK: smart actions

    @ViewBuilder
    private func smartActions(_ plain: String, clip: Clip) -> some View {
        let url = TextDetector.firstURL(in: plain)
        let email = TextDetector.firstEmail(in: plain)
        let firstFile = clip.kind == .file ? clip.fileURLArray.first : nil
        let hasAny = url != nil || email != nil || firstFile != nil
        if hasAny {
            HStack(spacing: 8) {
                if let url {
                    Button {
                        NSWorkspace.shared.open(url)
                    } label: {
                        Label("Open URL", systemImage: "safari")
                    }
                }
                if let email {
                    Button {
                        if let url = URL(string: "mailto:\(email)") {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        Label("Email \(email)", systemImage: "envelope")
                    }
                }
                if let firstFile,
                   FileManager.default.fileExists(atPath: firstFile.path) {
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting(clip.fileURLArray)
                    } label: {
                        Label("Reveal in Finder", systemImage: "folder")
                    }
                }
                Spacer()
            }
        }
    }

    // MARK: transforms

    @ViewBuilder
    private func transforms(_ plain: String) -> some View {
        let all: [TextDetector.Transform] = [
            .lowercase, .uppercase, .trim, .prettyJSON,
            .base64Encode, .base64Decode, .urlEncode, .urlDecode
        ]
        let applicable = all.filter { $0.applies(to: plain) }
        if !applicable.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Quick transforms")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                FlowLayout(spacing: 6) {
                    ForEach(applicable, id: \.label) { t in
                        Button {
                            apply(t, on: plain)
                        } label: {
                            Label(t.label, systemImage: t.symbol)
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
    }

    private func apply(_ transform: TextDetector.Transform, on s: String) {
        guard let result = transform.apply(to: s) else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(result, forType: .string)
        // Also persist the transformed version so it shows up in history.
        let clip = Clip.text(result, sourceBundleID: nil)
        try? environment.clipRepository.upsert(clip)
    }

    // MARK: text stats

    private func textStats(_ s: String) -> some View {
        HStack(spacing: 14) {
            stat(label: "chars", value: "\(s.count)")
            stat(label: "words", value: "\(TextDetector.wordCount(s))")
            stat(label: "lines", value: "\(TextDetector.lineCount(s))")
        }
        .foregroundStyle(.secondary)
        .font(.caption.monospacedDigit())
    }

    private func stat(label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(value).foregroundStyle(.primary)
            Text(label)
        }
    }

    // MARK: metadata

    private func metadata(_ clip: Clip) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            row("Captured", clip.createdAt.formatted(date: .abbreviated, time: .shortened))
            row("Last seen", clip.lastSeenAt.formatted(date: .abbreviated, time: .shortened))
            if clip.hitCount > 1 { row("Times seen", "\(clip.hitCount)") }
            if let bid = clip.sourceBundleID {
                HStack {
                    Text("From").foregroundStyle(.tertiary)
                    Spacer()
                    HStack(spacing: 4) {
                        AppIconView(bundleID: bid, size: 14)
                        Text(bid).foregroundStyle(.secondary)
                    }
                }
            }
            row("Size", ByteCountFormatter.string(fromByteCount: Int64(clip.byteSize), countStyle: .file))
            if clip.isEncrypted { row("Encrypted", "Yes (ChaCha20-Poly1305)") }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.tertiary)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
    }

    // MARK: tags

    @ViewBuilder
    private func tagsRow(_ clip: Clip) -> some View {
        TagsAssigner(clip: clip, environment: environment)
    }
}

/// Inline tag chips with an "Add" menu listing all known tags. Toggling
/// a chip adds/removes the link.
private struct TagsAssigner: View {
    let clip: Clip
    let environment: AppEnvironment
    @State private var assigned: [Tag] = []
    @State private var allTags: [Tag] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Tags")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                ForEach(assigned, id: \.id) { tag in
                    chip(tag, removable: true) { remove(tag) }
                }
                Menu {
                    let assignedIDs = Set(assigned.map(\.id))
                    let unassigned = allTags.filter { !assignedIDs.contains($0.id) }
                    if unassigned.isEmpty {
                        Text("All tags applied")
                    } else {
                        ForEach(unassigned, id: \.id) { tag in
                            Button(tag.name) { add(tag) }
                        }
                    }
                } label: {
                    Label("Add Tag", systemImage: "plus.circle")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                Spacer()
            }
        }
        .onAppear(perform: reload)
    }

    private func chip(_ tag: Tag, removable: Bool, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: 4) {
            Circle().fill(Color(hex: tag.colorHex ?? "#9B8CFF") ?? .gray)
                .frame(width: 8, height: 8)
            Text(tag.name).font(.caption)
            if removable {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(.thinMaterial, in: Capsule())
    }

    private func reload() {
        Task.detached {
            let tagged = (try? environment.tagRepository.tags(forClip: clip.id)) ?? []
            let allRaw = (try? environment.tagRepository.all()) ?? []
            await MainActor.run {
                assigned = tagged
                allTags = allRaw
            }
        }
    }
    private func add(_ tag: Tag) {
        try? environment.tagRepository.add(tagID: tag.id, toClip: clip.id)
        reload()
    }
    private func remove(_ tag: Tag) {
        try? environment.tagRepository.remove(tagID: tag.id, fromClip: clip.id)
        reload()
    }
}

/// Minimal flow layout (wraps children to next line as needed). Used for
/// the transforms palette so chips wrap naturally to the available width.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x + size.width > maxW {
                x = 0
                y += lineHeight + spacing
                lineHeight = 0
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: maxW, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxW = bounds.width
        var x: CGFloat = bounds.minX, y: CGFloat = bounds.minY, lineHeight: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x + size.width > bounds.minX + maxW {
                x = bounds.minX
                y += lineHeight + spacing
                lineHeight = 0
            }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
