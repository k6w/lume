import SwiftUI

/// Settings pane for managing tags. Lives under its own Settings tab.
/// Lets you add a tag (with optional color), rename, delete, and see
/// how many clips reference it.
struct TagsPane: View {
    let environment: AppEnvironment
    @State private var rows: [(Tag, Int)] = []
    @State private var newName: String = ""
    @State private var newColor: Color = LumeTheme.accent

    var body: some View {
        Form {
            Section("Add tag") {
                HStack {
                    TextField("Name", text: $newName)
                        .textFieldStyle(.roundedBorder)
                    ColorPicker("", selection: $newColor, supportsOpacity: false)
                        .labelsHidden()
                    Button("Add") { add() }
                        .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            Section("Existing") {
                if rows.isEmpty {
                    Text("No tags yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(rows, id: \.0.id) { (tag, count) in
                        HStack {
                            Circle()
                                .fill(Color(hex: tag.colorHex ?? "#9B8CFF") ?? .gray)
                                .frame(width: 12, height: 12)
                            Text(tag.name)
                            Spacer()
                            Text("\(count)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                            Button {
                                try? environment.tagRepository.delete(id: tag.id)
                                reload()
                            } label: { Image(systemName: "trash").foregroundStyle(.red) }
                                .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: reload)
    }

    private func add() {
        let n = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty else { return }
        let tag = Tag(id: UUID().uuidString, name: n, colorHex: newColor.hexString)
        _ = try? environment.tagRepository.upsert(tag)
        newName = ""
        reload()
    }

    private func reload() {
        rows = (try? environment.tagRepository.tagCounts()) ?? []
    }
}
