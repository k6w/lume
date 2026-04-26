import SwiftUI

struct TagsPane: View {
    @Environment(LumeTheme.self) private var theme
    let environment: AppEnvironment
    @State private var rows: [(Tag, Int)] = []
    @State private var draft: Tag?

    var body: some View {
        Form {
            Section {
                Button {
                    draft = Tag(id: UUID().uuidString, name: "",
                                colorHex: theme.accent.hexString,
                                icon: "tag")
                } label: {
                    Label("New Tag…", systemImage: "plus.circle")
                }
            }
            Section("Existing") {
                if rows.isEmpty {
                    Text("No tags yet. Hit New Tag to start.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(rows, id: \.0.id) { (tag, count) in
                        HStack(spacing: 10) {
                            Image(systemName: tag.icon ?? "tag")
                                .foregroundStyle(Color(hex: tag.colorHex ?? "#7A70FF") ?? .gray)
                                .frame(width: 22, height: 22)
                                .background(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill((Color(hex: tag.colorHex ?? "#7A70FF") ?? .gray).opacity(0.14))
                                )
                            Text(tag.name)
                            Spacer()
                            Text("\(count)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                            Button {
                                draft = tag
                            } label: { Image(systemName: "pencil").foregroundStyle(.secondary) }
                                .buttonStyle(.plain)
                                .help("Edit")
                            Button {
                                try? environment.tagRepository.delete(id: tag.id)
                                reload()
                            } label: { Image(systemName: "trash").foregroundStyle(.red) }
                                .buttonStyle(.plain)
                                .help("Delete")
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: reload)
        .sheet(item: $draft) { tag in
            TagEditorSheet(
                tag: tag,
                title: tag.name.isEmpty ? "New Tag" : "Edit Tag",
                onSave: { saved in
                    _ = try? environment.tagRepository.upsert(saved)
                    draft = nil
                    reload()
                },
                onCancel: { draft = nil }
            )
        }
    }

    private func reload() {
        rows = (try? environment.tagRepository.tagCounts()) ?? []
    }
}
