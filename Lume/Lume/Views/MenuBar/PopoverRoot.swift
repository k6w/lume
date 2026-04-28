import SwiftUI
import GRDB
import AppKit

/// Root view inside the menu-bar popover. Holds search state, drives the
/// virtualized history list, and ferries actions back to the AppKit shell.
@MainActor
struct PopoverRoot: View {
    @LumeAccent private var accent
    let clipRepository: ClipRepository
    let snippetRepository: SnippetRepository
    let fts: FullTextSearch
    let encryption: EncryptionService
    var onPaste: (Clip) -> Void
    var onPin: (Clip) -> Void
    var onDelete: (Clip) -> Void
    var onOpenMain: () -> Void
    var onSnippetPaste: (Snippet) -> Void

    @State private var query: String = ""
    @State private var clips: [Clip] = []
    @State private var snippets: [Snippet] = []
    @State private var selection: String?
    @State private var observationTask: Task<Void, Never>?
    @State private var snippetTask: Task<Void, Never>?
    @State private var lastCaptureID: String?
    @State private var captureFlash = false

    var body: some View {
        rootContent
            .tint(accent)
    }

    private var rootContent: some View {
        GlassRoot {
            VStack(spacing: 0) {
                header
                Divider().opacity(0.25)
                if clips.isEmpty {
                    emptyState
                } else {
                    HistoryList(
                        clips: clips,
                        selection: $selection,
                        onPaste: onPaste,
                        onPin: onPin,
                        onDelete: onDelete
                    )
                    .frame(maxHeight: .infinity)
                }
                Divider().opacity(0.25)
                footer
            }
            .overlay(alignment: .top) { captureToast }
        }
        .frame(width: Tokens.Sizing.popoverWidth, height: Tokens.Sizing.popoverHeight)
        .onAppear {
            startObservation()
            startSnippetObservation()
        }
        .onDisappear {
            observationTask?.cancel()
            snippetTask?.cancel()
        }
        .onChange(of: query) { _, _ in refresh() }
        // Quick-paste: ⌘1...⌘9 paste the corresponding visible row.
        .background {
            ForEach(1...9, id: \.self) { idx in
                Button("paste-\(idx)") { activate(at: idx - 1) }
                    .keyboardShortcut(KeyEquivalent(Character("\(idx)")), modifiers: [.command])
                    .opacity(0).frame(width: 0, height: 0)
            }
        }
    }

    private var header: some View {
        HStack(spacing: Tokens.Spacing.s) {
            LumeSearchField(
                text: $query,
                onSubmit: { activateSelection() },
                onArrow: { dir in
                    switch dir {
                    case .up:        moveSelection(by: -1)
                    case .down:      moveSelection(by:  1)
                    case .returnKey: activateSelection()
                    case .escape:    NSApp.keyWindow?.close()
                    }
                }
            )
            .frame(height: 28)
        }
        .padding(.horizontal, Tokens.Spacing.m)
        .padding(.vertical, Tokens.Spacing.s)
    }

    private var emptyState: some View {
        VStack(spacing: Tokens.Spacing.m) {
            Spacer()
            Image(systemName: query.isEmpty ? "sparkles" : "magnifyingglass")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(accent)
            Text(query.isEmpty ? "Nothing here yet" : "No matches")
                .font(.headline)
            Text(query.isEmpty
                 ? "Copy something and Lume will catch it."
                 : "Try a different search term.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Tokens.Spacing.xl)
    }

    private var footer: some View {
        HStack(spacing: Tokens.Spacing.m) {
            Text("⌘↩ paste").font(.caption2)
            Text("⌘1–9 quick").font(.caption2)
            Spacer()
            snippetMenu
            Button {
                onOpenMain()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "rectangle.expand.vertical")
                    Text("Open Lume")
                }.font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(accent)
        }
        .padding(.horizontal, Tokens.Spacing.m)
        .padding(.vertical, Tokens.Spacing.s)
        .foregroundStyle(.secondary)
    }

    private var snippetMenu: some View {
        Menu {
            if snippets.isEmpty {
                Text("No snippets yet")
            } else {
                ForEach(snippets, id: \.id) { snippet in
                    Button {
                        onSnippetPaste(snippet)
                    } label: {
                        Label(snippet.title, systemImage: "text.append")
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "text.append")
                Text("Snippets").font(.caption)
            }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .foregroundStyle(accent)
    }

    @ViewBuilder private var captureToast: some View {
        if captureFlash {
            HStack(spacing: 6) {
                Image(systemName: "sparkle")
                Text("Captured")
            }
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(.ultraThinMaterial,
                        in: Capsule(style: .continuous))
            .padding(.top, 6)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    // MARK: Data

    private func startObservation() {
        observationTask?.cancel()
        observationTask = Task { @MainActor in
            do {
                let observation = clipRepository.observeRecent(limit: 50)
                for try await fresh in observation.values(in: clipRepository.pool) {
                    let resolved = fresh.map { encryption.open($0) }
                    let isNew = resolved.first?.id != lastCaptureID && lastCaptureID != nil
                    self.clips = resolved
                    if selection == nil { selection = resolved.first?.id }
                    if isNew { flashCapture() }
                    lastCaptureID = resolved.first?.id
                }
            } catch {
                NSLog("[Lume] observe failed: \(error)")
            }
        }
    }

    private func startSnippetObservation() {
        snippetTask?.cancel()
        snippetTask = Task { @MainActor in
            do {
                let observation = snippetRepository.observeAll()
                for try await fresh in observation.values(in: snippetRepository.pool) {
                    self.snippets = fresh
                }
            } catch {
                NSLog("[Lume] snippet observe failed: \(error)")
            }
        }
    }

    private func flashCapture() {
        withAnimation(.easeOut(duration: 0.18)) { captureFlash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeIn(duration: 0.2)) { captureFlash = false }
        }
    }

    private func refresh() {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty {
            startObservation()
            return
        }
        observationTask?.cancel()
        Task { @MainActor in
            do {
                let raw = try fts.search(q, limit: 80)
                clips = raw.map { encryption.open($0) }
                selection = clips.first?.id
            } catch {
                NSLog("[Lume] fts failed: \(error)")
            }
        }
    }

    private func moveSelection(by offset: Int) {
        guard let current = selection,
              let idx = clips.firstIndex(where: { $0.id == current }) else {
            selection = clips.first?.id
            return
        }
        let next = max(0, min(clips.count - 1, idx + offset))
        selection = clips[next].id
    }

    private func activateSelection() {
        guard let id = selection,
              let clip = clips.first(where: { $0.id == id }) else { return }
        onPaste(clip)
    }

    private func activate(at index: Int) {
        guard index >= 0, index < clips.count else { return }
        onPaste(clips[index])
    }
}
