import SwiftUI
import GRDB

struct SnippetsView: View {
    let environment: AppEnvironment
    @State private var snippets: [Snippet] = []
    @State private var draft: Snippet?
    @State private var observationTask: Task<Void, Never>?
    @State private var hoveredID: String?
    @State private var pendingDelete: Snippet?

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.s) {
            HStack {
                Text("Snippets").font(.title2.weight(.semibold))
                Spacer()
                Button {
                    draft = Snippet(id: UUID().uuidString, title: "New Snippet", body: "",
                                    shortcut: nil, kind: .text, updatedAt: Date())
                } label: {
                    Label("New Snippet", systemImage: "plus")
                }
                .keyboardShortcut("n")
            }
            .padding(.horizontal, Tokens.Spacing.l)
            .padding(.top, Tokens.Spacing.l)

            if snippets.isEmpty {
                empty
            } else {
                List {
                    ForEach(snippets, id: \.id) { snippet in
                        row(snippet)
                            .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.inset)
            }

            Text("Variables: `{{date}}` `{{time}}` `{{datetime}}` `{{clipboard}}`")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, Tokens.Spacing.l)
                .padding(.bottom, Tokens.Spacing.m)
        }
        .navigationTitle("Snippets")
        .onAppear { startObservation() }
        .onDisappear { observationTask?.cancel() }
        .sheet(item: $draft) { snippet in
            SnippetEditor(snippet: snippet) { saved in
                _ = try? environment.snippetRepository.save(saved)
                draft = nil
            } onCancel: {
                draft = nil
            }
        }
        .alert("Delete this snippet?",
               isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
               ),
               presenting: pendingDelete) { snippet in
            Button("Delete", role: .destructive) {
                try? environment.snippetRepository.delete(id: snippet.id)
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: { snippet in
            Text("\"\(snippet.title)\" will be removed. This cannot be undone.")
        }
    }

    private func row(_ snippet: Snippet) -> some View {
        let isHovered = hoveredID == snippet.id
        return HStack(spacing: 12) {
            Image(systemName: "text.append")
                .foregroundStyle(LumeTheme.accent)
                .frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(snippet.title).font(.headline)
                Text(snippet.body)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(.secondary)
                    .font(.system(.body, design: .monospaced))
            }
            Spacer()
            if let s = snippet.shortcut, !s.isEmpty {
                Text(s)
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(.thinMaterial,
                                in: RoundedRectangle(cornerRadius: 4))
            }
            HStack(spacing: 6) {
                Button {
                    draft = snippet
                } label: { Image(systemName: "pencil") }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Edit")
                Button {
                    pendingDelete = snippet
                } label: { Image(systemName: "trash") }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                    .help("Delete")
            }
            .opacity(isHovered ? 1 : 0.0001) // hold a frame to keep layout stable
            .animation(.easeInOut(duration: 0.12), value: isHovered)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onHover { h in hoveredID = h ? snippet.id : (hoveredID == snippet.id ? nil : hoveredID) }
        .contextMenu {
            Button("Edit") { draft = snippet }
            Button("Copy expanded text") {
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setString(SnippetExpander.expand(snippet.body), forType: .string)
                environment.pasteInjector.markOwned()
            }
            Divider()
            Button(role: .destructive) {
                pendingDelete = snippet
            } label: { Text("Delete") }
        }
    }

    private var empty: some View {
        EmptyStateView(
            symbol: "text.append",
            title: "No snippets yet",
            subtitle: "Save reusable text — signatures, boilerplate, anything you paste often."
        )
    }

    private func startObservation() {
        observationTask?.cancel()
        observationTask = Task { @MainActor in
            do {
                let observation = environment.snippetRepository.observeAll()
                for try await fresh in observation.values(in: environment.snippetRepository.pool) {
                    self.snippets = fresh
                }
            } catch {
                NSLog("[Lume] snippets observe failed: \(error)")
            }
        }
    }
}

private struct SnippetEditor: View {
    @State var snippet: Snippet
    var onSave: (Snippet) -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(spacing: Tokens.Spacing.m) {
            HStack {
                TextField("Title", text: $snippet.title)
                    .textFieldStyle(.roundedBorder)
                TextField("Shortcut (optional)", text: Binding(
                    get: { snippet.shortcut ?? "" },
                    set: { snippet.shortcut = $0.isEmpty ? nil : $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(width: 160)
            }
            TextEditor(text: $snippet.body)
                .frame(minHeight: 240)
                .font(.system(.body, design: .monospaced))
                .padding(8)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            Text("Variables: `{{date}}` `{{time}}` `{{datetime}}` `{{clipboard}}`")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                Button("Save") { onSave(snippet) }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return)
                    .disabled(snippet.title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(Tokens.Spacing.l)
        .frame(width: 560, height: 420)
    }
}
