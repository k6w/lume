import SwiftUI

enum SidebarItem: String, Hashable, CaseIterable, Identifiable {
    case all       = "All Clips"
    case pinned    = "Pinned"
    // Smart (computed via NSDataDetector at filter time)
    case urls      = "URLs"
    case emails    = "Emails"
    case today     = "Today"
    case thisWeek  = "This Week"
    // Types
    case files     = "Files"
    case colors    = "Colors"
    case images    = "Images"
    // Tools
    case snippets  = "Snippets"
    case stats     = "Stats"
    case settings  = "Settings"

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .all:      return "tray.full"
        case .pinned:   return "pin.fill"
        case .urls:     return "link"
        case .emails:   return "envelope"
        case .today:    return "sun.max"
        case .thisWeek: return "calendar"
        case .images:   return "photo"
        case .files:    return "doc"
        case .colors:   return "paintpalette"
        case .snippets: return "text.append"
        case .stats:    return "chart.bar"
        case .settings: return "gearshape"
        }
    }
}

/// Custom sidebar that *looks* native (List(.sidebar) chrome with section
/// headers and the sidebar material) but doesn't hand selection to the
/// system. Each row is a `Button` that updates the parent's binding —
/// the native selection rectangle never appears, so our accent
/// `.listRowBackground` is the *only* highlight you see. Arrow-key
/// navigation is implemented by hand against `visibleItems`.
struct Sidebar: View {
    @LumeAccent private var accent
    @Binding var selection: SidebarItem
    @AppStorage(CaptureSettings.Key.captureImages.rawValue) private var captureImages: Bool = false
    @FocusState private var focused: Bool

    private var visibleItems: [SidebarItem] {
        var items: [SidebarItem] = [.all, .pinned,
                                    .urls, .emails, .today, .thisWeek,
                                    .files, .colors]
        if captureImages { items.append(.images) }
        items += [.snippets, .stats, .settings]
        return items
    }

    var body: some View {
        List {
            Section("Library") {
                row(.all)
                row(.pinned)
            }
            Section("Smart") {
                row(.urls)
                row(.emails)
                row(.today)
                row(.thisWeek)
            }
            Section("Types") {
                row(.files)
                row(.colors)
                if captureImages {
                    row(.images)
                }
            }
            Section {
                row(.snippets)
                row(.stats)
                row(.settings)
            }
        }
        .listStyle(.sidebar)
        .focusable()
        .focused($focused)
        .onAppear { focused = true }
        // Arrow-key nav: List handles this for free when you give it a
        // `selection:` binding — but that brings back the native red
        // selection rect we worked so hard to remove. Reimplement here.
        .onKeyPress(.upArrow) {
            move(by: -1); return .handled
        }
        .onKeyPress(.downArrow) {
            move(by: 1); return .handled
        }
    }

    private func move(by offset: Int) {
        let items = visibleItems
        guard let idx = items.firstIndex(of: selection) else {
            selection = items.first ?? .all
            return
        }
        let next = max(0, min(items.count - 1, idx + offset))
        selection = items[next]
    }

    @ViewBuilder
    private func row(_ item: SidebarItem) -> some View {
        let isSelected = selection == item
        Button {
            selection = item
        } label: {
            HStack(spacing: 8) {
                Image(systemName: item.symbol)
                    .foregroundStyle(isSelected ? AnyShapeStyle(accent) : AnyShapeStyle(.secondary))
                    .frame(width: 16)
                Text(item.rawValue)
                    // Always .primary — full contrast against the accent
                    // backdrop. Selection is signalled by accent-icon and
                    // semibold weight, not by tinting the text.
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
}
