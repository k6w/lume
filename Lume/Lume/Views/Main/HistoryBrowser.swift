import SwiftUI
import GRDB

/// Two-pane browser inside the main window: a `List(selection:)` of clips
/// on the left, the detail pane on the right.
///
///  - **Single click** → selects, shows in the detail pane.
///  - **Double click** → pastes (and bounces the active app).
///  - Right-click → Pin / Delete / Copy as Plain Text.
///
/// Search query and "currently focused clip id" come from MainWindow as
/// `@Binding`s so the hoisted toolbar (Copy + Search) stays in sync
/// across every tab.
struct HistoryBrowser: View {
    @LumeAccent private var accent
    let environment: AppEnvironment
    let scope: SidebarItem
    @Binding var query: String
    @Binding var focusedClipID: String?
    @Binding var tagFilter: TagFilter

    @State private var clips: [Clip] = []
    @State private var selection: String?
    @State private var observationTask: Task<Void, Never>?
    @State private var tagsByClip: [String: Set<String>] = [:]
    @State private var tagsObservationTask: Task<Void, Never>?
    @FocusState private var listFocused: Bool

    var body: some View {
        HSplitView {
            listPane
                .frame(minWidth: 320, idealWidth: 420)
            detailPane
                .frame(minWidth: 320)
        }
        .navigationTitle(scope.rawValue)
        .onAppear {
            startObservation()
            startTagsObservation()
        }
        .onDisappear {
            observationTask?.cancel()
            tagsObservationTask?.cancel()
        }
        .onChange(of: selection) { _, newValue in focusedClipID = newValue }
        .onChange(of: focused?.id) { _, _ in /* triggers redraw */ }
    }

    private var listPane: some View {
        Group {
            if filtered.isEmpty {
                emptyState
            } else {
                ScrollViewReader { proxy in
                    List {
                        ForEach(filtered, id: \.id) { clip in
                            row(clip)
                        }
                    }
                    .listStyle(.inset)
                    .focusable()
                    .focused($listFocused)
                    .onAppear { listFocused = true }
                    .onKeyPress(.upArrow)   { move(by: -1, proxy: proxy); return .handled }
                    .onKeyPress(.downArrow) { move(by:  1, proxy: proxy); return .handled }
                    .onChange(of: selection) { _, newID in
                        if let id = newID {
                            withAnimation(.easeInOut(duration: 0.12)) {
                                proxy.scrollTo(id, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func row(_ clip: Clip) -> some View {
        let isSelected = selection == clip.id
        Button {
            selection = clip.id
        } label: {
            // Text stays .primary for contrast against the accent backdrop.
            // The ClipListItem already tints its kind icon with accent,
            // which is enough of a selection signal.
            ClipListItem(clip: clip)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .id(clip.id)
        .listRowSeparator(.hidden)
        .listRowBackground(
            Group {
                if isSelected {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(accent.opacity(0.22))
                        .padding(.horizontal, 4)
                } else {
                    Color.clear
                }
            }
        )
        .contextMenu {
            Button("Copy") { environment.pasteInjector.copy(clip) }
            Button("Copy as Plain Text") {
                environment.pasteInjector.copyAsPlainText(clip)
            }
            Button(clip.isPinned ? "Unpin" : "Pin") { pin(clip) }
            Divider()
            Button(role: .destructive) { delete(clip) } label: {
                Text("Delete")
            }
        }
    }

    private func move(by offset: Int, proxy: ScrollViewProxy) {
        let list = filtered
        guard !list.isEmpty else { return }
        guard let current = selection,
              let idx = list.firstIndex(where: { $0.id == current })
        else {
            selection = list.first?.id
            return
        }
        let next = max(0, min(list.count - 1, idx + offset))
        selection = list[next].id
    }

    private var detailPane: some View {
        HistoryDetail(clip: focused, environment: environment)
            .id(focused?.id ?? "_none_")
    }

    private var focused: Clip? {
        guard let id = selection else { return filtered.first }
        return filtered.first { $0.id == id }
    }

    private var emptyState: some View {
        EmptyStateView(
            symbol: emptySymbol,
            title: query.isEmpty ? emptyTitle : "No matches",
            subtitle: query.isEmpty ? emptySubtitle : "Try a different search term."
        )
    }

    private var emptySymbol: String {
        switch scope {
        case .pinned:   return "pin"
        case .urls:     return "link"
        case .emails:   return "envelope"
        case .today:    return "sun.max"
        case .thisWeek: return "calendar"
        case .images:   return "photo"
        case .files:    return "doc"
        case .colors:   return "paintpalette"
        default:        return "tray"
        }
    }
    private var emptyTitle: String {
        switch scope {
        case .pinned:   return "Nothing pinned"
        case .urls:     return "No URLs yet"
        case .emails:   return "No emails yet"
        case .today:    return "Nothing today"
        case .thisWeek: return "Nothing this week"
        case .images:   return "No images"
        case .files:    return "No files"
        case .colors:   return "No colors"
        default:        return "Nothing here yet"
        }
    }
    private var emptySubtitle: String {
        switch scope {
        case .pinned:   return "Star a clip to keep it forever — pinned clips survive auto-purge."
        case .urls:     return "Anything you copy that contains a URL will land here."
        case .emails:   return "Email addresses you copy show up here automatically."
        case .today:    return "Clips you've copied today."
        case .thisWeek: return "Clips from the last 7 days."
        case .images:   return "Enable image capture in Settings → Data to start collecting screenshots."
        case .files:    return "Copy a file in Finder and it'll appear here."
        case .colors:   return "Hex codes and color-picker output land here."
        default:        return "Anything you copy will show up automatically."
        }
    }

    private var filtered: [Clip] {
        let scopeFiltered: [Clip]
        let now = Date()
        let cal = Calendar.current
        switch scope {
        case .pinned:   scopeFiltered = clips.filter(\.isPinned)
        case .images:   scopeFiltered = clips.filter { $0.kind == .image }
        case .files:    scopeFiltered = clips.filter { $0.kind == .file }
        case .colors:   scopeFiltered = clips.filter { $0.kind == .color }
        case .urls:     scopeFiltered = clips.filter { TextDetector.containsURL($0.plainText ?? "") }
        case .emails:   scopeFiltered = clips.filter { TextDetector.containsEmail($0.plainText ?? "") }
        case .today:    scopeFiltered = clips.filter { cal.isDateInToday($0.lastSeenAt) }
        case .thisWeek: scopeFiltered = clips.filter { cal.isDate($0.lastSeenAt, equalTo: now, toGranularity: .weekOfYear) }
        default:        scopeFiltered = clips
        }

        let tagFiltered: [Clip]
        switch tagFilter {
        case .all:
            tagFiltered = scopeFiltered
        case .untagged:
            tagFiltered = scopeFiltered.filter { (tagsByClip[$0.id]?.isEmpty ?? true) }
        case .tagID(let id):
            tagFiltered = scopeFiltered.filter { tagsByClip[$0.id]?.contains(id) ?? false }
        }

        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return tagFiltered }
        return tagFiltered.filter {
            ($0.plainText?.lowercased().contains(q) ?? false) ||
            ($0.sourceBundleID?.lowercased().contains(q) ?? false) ||
            ($0.colorHex?.lowercased().contains(q) ?? false)
        }
    }

    // MARK: actions

    private func pin(_ clip: Clip) {
        try? environment.clipRepository.setPinned(!clip.isPinned, id: clip.id)
    }
    private func delete(_ clip: Clip) {
        try? environment.clipRepository.delete(id: clip.id)
        if selection == clip.id { selection = nil }
    }

    private func startTagsObservation() {
        tagsObservationTask?.cancel()
        tagsObservationTask = Task { @MainActor in
            do {
                let observation = environment.tagRepository.observeTagsByClip()
                for try await fresh in observation.values(in: environment.tagRepository.pool) {
                    self.tagsByClip = fresh
                }
            } catch {
                NSLog("[Lume] tags-by-clip observe failed: \(error)")
            }
        }
    }

    private func startObservation() {
        observationTask?.cancel()
        observationTask = Task { @MainActor in
            do {
                let observation = environment.clipRepository.observeRecent(limit: 200)
                let encryption = environment.encryption
                for try await fresh in observation.values(in: environment.clipRepository.pool) {
                    // Unseal sealed rows here so the rest of the view tree
                    // can read plainText/rtfData/htmlData uniformly.
                    let resolved = fresh.map { encryption.open($0) }
                    self.clips = resolved
                    if selection == nil || !resolved.contains(where: { $0.id == selection }) {
                        selection = resolved.first?.id
                    }
                }
            } catch {
                NSLog("[Lume] observe failed: \(error)")
            }
        }
    }
}

private struct ClipListItem: View {
    @LumeAccent private var accent
    let clip: Clip

    var body: some View {
        HStack(alignment: .top, spacing: Tokens.Spacing.m) {
            Image(systemName: clip.kind.sfSymbol)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(accent)
                .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 2) {
                ClipPreview(clip: clip, compact: true)
                meta
            }
            Spacer(minLength: 0)
            if clip.isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption2)
                    .rotationEffect(.degrees(45))
                    .foregroundStyle(accent)
            }
        }
        .padding(.vertical, 4)
    }

    private var meta: some View {
        HStack(spacing: 6) {
            if let bid = clip.sourceBundleID {
                Text(bid.split(separator: ".").last.map(String.init) ?? bid)
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
        }
    }
}
