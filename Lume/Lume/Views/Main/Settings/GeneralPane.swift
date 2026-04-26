import SwiftUI

struct GeneralPane: View {
    @AppStorage("lume.launchAtLogin")  private var launchAtLogin: Bool = true
    @AppStorage("lume.plainTextPaste") private var plainTextPaste: Bool = false
    @AppStorage("lume.showInDock")     private var showInDock: Bool = false
    @State private var accent: Color = LumeTheme.accent

    var body: some View {
        Form {
            Section("Behavior") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                Toggle("Always paste as plain text", isOn: $plainTextPaste)
                Toggle("Show Lume in the Dock", isOn: $showInDock)
            }
            Section("Appearance") {
                ColorPicker("Accent", selection: $accent, supportsOpacity: false)
                    .onChange(of: accent) { _, new in LumeTheme.accent = new }
            }
        }
        .formStyle(.grouped)
    }
}
