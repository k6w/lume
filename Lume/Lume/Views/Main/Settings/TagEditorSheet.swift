import SwiftUI

/// Modal sheet for creating or editing a tag — name, icon, color.
/// Presented from Settings → Tags and from the detail pane "New Tag…"
/// menu item, so users can spin up a tag from wherever they are.
struct TagEditorSheet: View {
    @State var draft: Tag
    var title: String = "New Tag"
    var onSave: (Tag) -> Void
    var onCancel: () -> Void

    @State private var color: Color

    init(tag: Tag,
         title: String = "New Tag",
         onSave: @escaping (Tag) -> Void,
         onCancel: @escaping () -> Void)
    {
        self._draft = State(initialValue: tag)
        self.title = title
        self.onSave = onSave
        self.onCancel = onCancel
        let resolved = Color(hex: tag.colorHex ?? "") ?? LumeTheme.accent
        self._color = State(initialValue: resolved)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(color.opacity(0.16))
                    Image(systemName: draft.icon ?? "tag")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(color)
                }
                .frame(width: 44, height: 44)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(color.opacity(0.3))
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    Text(draft.name.isEmpty ? "Pick a name and an icon" : draft.name)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(Tokens.Spacing.l)

            Divider()

            Form {
                Section {
                    TextField("Name", text: $draft.name)
                        .textFieldStyle(.roundedBorder)
                    ColorPicker("Color", selection: $color, supportsOpacity: false)
                        .onChange(of: color) { _, c in draft.colorHex = c.hexString }
                }
                Section("Icon") {
                    SFSymbolPicker(selection: Binding(
                        get: { draft.icon ?? "tag" },
                        set: { draft.icon = $0 }
                    ), tint: color)
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                Button("Save") {
                    var tag = draft
                    tag.name = tag.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    if tag.name.isEmpty { return }
                    if tag.icon == nil { tag.icon = "tag" }
                    if tag.colorHex == nil { tag.colorHex = color.hexString }
                    onSave(tag)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return)
                .disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(Tokens.Spacing.l)
        }
        .frame(width: 540, height: 580)
    }
}
