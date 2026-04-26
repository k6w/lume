import SwiftUI

struct SnippetsView: View {
    let environment: AppEnvironment
    @State private var snippets: [Snippet] = []
    @State private var draft: Snippet?

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.m) {
            HStack {
                Text("Snippets").font(.title2.weight(.semibold))
                Spacer()
                Button {
                    draft = Snippet(id: UUID().uuidString, title: "New Snippet", body: "",
                                    shortcut: nil, kind: .text, updatedAt: Date())
                } label: {
                    Label("New", systemImage: "plus")
                }
                .keyboardShortcut("n")
            }
            if snippets.isEmpty {
                empty
            } else {
                List(snippets, id: \.id) { snippet in
                    HStack {
                        Image(systemName: "text.append").foregroundStyle(LumeTheme.accent)
                        VStack(alignment: .leading) {
                            Text(snippet.title).font(.headline)
                            Text(SnippetExpander.expand(snippet.body))
                                .lineLimit(1)
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
                    }
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) { paste(snippet) }
                    .contextMenu {
                        Button("Paste") { paste(snippet) }
                        Button("Edit") { draft = snippet }
                        Button("Copy") {
                            let expanded = SnippetExpander.expand(snippet.body)
                            let pb = NSPasteboard.general
                            pb.clearContents()
                            pb.setString(expanded, forType: .string)
                        }
                        Divider()
                        Button(role: .destructive) {
                            try? environment.snippetRepository.delete(id: snippet.id)
                            reload()
                        } label: { Text("Delete") }
                    }
                }
                .listStyle(.inset)
            }

            Text("Variables: `{{date}}` `{{time}}` `{{datetime}}` `{{clipboard}}`")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 4)
        }
        .padding(Tokens.Spacing.l)
        .navigationTitle("Snippets")
        .onAppear(perform: reload)
        .sheet(item: $draft) { snippet in
            SnippetEditor(snippet: snippet) { saved in
                _ = try? environment.snippetRepository.save(saved)
                reload()
                draft = nil
            } onCancel: {
                draft = nil
            }
        }
    }

    private var empty: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "text.append").font(.system(size: 36, weight: .light))
                .foregroundStyle(LumeTheme.accent)
            Text("No snippets yet").font(.title3)
            Text("Save reusable text — signatures, boilerplate, anything you paste often.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func paste(_ snippet: Snippet) {
        let expanded = SnippetExpander.expand(snippet.body)
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(expanded, forType: .string)
        environment.pasteInjector.simulatePaste()
    }

    private func reload() {
        snippets = (try? environment.snippetRepository.all()) ?? []
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
            }
        }
        .padding(Tokens.Spacing.l)
        .frame(width: 560, height: 420)
    }
}
