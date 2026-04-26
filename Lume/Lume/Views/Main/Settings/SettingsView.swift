import SwiftUI

/// Settings layout: HSplitView with a hand-rolled tab list on the left
/// (so the selection wears our accent, not NSColor.controlAccentColor)
/// and a Form-pane on the right. We can't nest a `NavigationSplitView`
/// inside the main window's outer one — SwiftUI explicitly does not
/// support that — so this is the right primitive.
struct SettingsView: View {
    @LumeAccent private var accent
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
    @FocusState private var focused: Bool

    var body: some View {
        HSplitView {
            tabList
                .frame(minWidth: 170, idealWidth: 200, maxWidth: 240)
            ScrollView {
                Group {
                    switch selection {
                    case .general: GeneralPane(environment: environment)
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

    private var tabList: some View {
        List {
            ForEach(Tab.allCases) { tab in
                tabRow(tab)
            }
        }
        .listStyle(.sidebar)
        .focusable()
        .focused($focused)
        .onAppear { focused = true }
        .onKeyPress(.upArrow) {
            move(by: -1); return .handled
        }
        .onKeyPress(.downArrow) {
            move(by: 1); return .handled
        }
    }

    @ViewBuilder
    private func tabRow(_ tab: Tab) -> some View {
        let isSelected = selection == tab
        Button {
            selection = tab
        } label: {
            HStack(spacing: 8) {
                Image(systemName: tab.symbol)
                    .foregroundStyle(isSelected ? AnyShapeStyle(accent) : AnyShapeStyle(.secondary))
                    .frame(width: 16)
                Text(tab.rawValue)
                    .foregroundStyle(.primary)
                    .fontWeight(isSelected ? .semibold : .regular)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(
            Group {
                if isSelected {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(accent.opacity(0.22))
                        .padding(.horizontal, 6)
                } else {
                    Color.clear
                }
            }
        )
    }

    private func move(by offset: Int) {
        let items = Tab.allCases
        guard let idx = items.firstIndex(of: selection) else { return }
        let next = max(0, min(items.count - 1, idx + offset))
        selection = items[next]
    }
}
