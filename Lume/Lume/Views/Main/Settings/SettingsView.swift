import SwiftUI

/// Settings, redone. Uses `HSplitView` with a sidebar `List(selection:)`.
/// We CAN'T nest a `NavigationSplitView` inside the main window's outer
/// `NavigationSplitView` — SwiftUI explicitly does not support that and
/// the previous version was rendering as an empty pane.
struct SettingsView: View {
    let environment: AppEnvironment

    enum Tab: String, Hashable, CaseIterable, Identifiable {
        case general = "General"
        case privacy = "Privacy"
        case tags    = "Tags"
        case hotkeys = "Hot Keys"
        case data    = "Data & iCloud"

        var id: String { rawValue }
        var symbol: String {
            switch self {
            case .general: return "gearshape"
            case .privacy: return "lock.shield"
            case .tags:    return "tag"
            case .hotkeys: return "keyboard"
            case .data:    return "icloud"
            }
        }
    }

    @State private var selection: Tab = .general

    var body: some View {
        HSplitView {
            List(Tab.allCases, selection: $selection) { tab in
                Label(tab.rawValue, systemImage: tab.symbol)
                    .tag(tab)
            }
            .listStyle(.sidebar)
            .frame(minWidth: 170, idealWidth: 200, maxWidth: 240)

            ScrollView {
                Group {
                    switch selection {
                    case .general: GeneralPane()
                    case .privacy: PrivacyPane(environment: environment)
                    case .tags:    TagsPane(environment: environment)
                    case .hotkeys: HotkeysPane(environment: environment)
                    case .data:    DataPane(environment: environment)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minWidth: 420)
        }
        .navigationTitle("Settings")
    }
}
