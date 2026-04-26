import SwiftUI
import AppKit

struct GeneralPane: View {
    @LumeAccent private var accent
    let environment: AppEnvironment

    @AppStorage("lume.launchAtLogin")  private var launchAtLogin: Bool = true
    @AppStorage("lume.plainTextPaste") private var plainTextPaste: Bool = false
    @AppStorage("lume.showInDock")     private var showInDock: Bool = false
    @AppStorage(PopoverStyle.storageKey) private var popoverStyleRaw: String = PopoverStyle.default.rawValue

    private var popoverStyle: PopoverStyle {
        PopoverStyle(rawValue: popoverStyleRaw) ?? .default
    }

    var body: some View {
        Form {
            Section("Behavior") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                Toggle("Always paste as plain text", isOn: $plainTextPaste)
                Toggle("Show Lume in the Dock", isOn: $showInDock)
            }
            Section("Appearance") {
                // `$accent` is the projectedValue from @LumeAccent — a
                // Binding<Color> that writes back through the same
                // UserDefaults key every other view observes.
                ColorPicker("Accent", selection: $accent, supportsOpacity: false)
                Button("Reset to default") {
                    LumeTheme.accent = Tokens.Brand.indigo
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
            }
            Section("Popover style") {
                Picker("Layout", selection: $popoverStyleRaw) {
                    ForEach(PopoverStyle.allCases) { style in
                        Text(style.displayName).tag(style.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                Text(popoverStyle.blurb)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section("Updates") {
                LabeledContent("Installed", value: "Lume \(environment.updateChecker.installedVersion)")
                if let latest = environment.updateChecker.latest {
                    LabeledContent("Latest on GitHub", value: latest.tag)
                }
                if let last = environment.updateChecker.lastCheckedAt {
                    LabeledContent("Last checked",
                                   value: last.formatted(.relative(presentation: .numeric)))
                }
                HStack {
                    Button {
                        Task { await environment.updateChecker.check() }
                    } label: {
                        if environment.updateChecker.isChecking {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("Check for Updates")
                        }
                    }
                    .disabled(environment.updateChecker.isChecking)
                    Spacer()
                    if environment.updateChecker.isUpdateAvailable,
                       let release = environment.updateChecker.latest {
                        Button {
                            NSWorkspace.shared.open(release.url)
                        } label: { Label("Download \(release.tag)", systemImage: "arrow.down.circle") }
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}
