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

/// Sidebar that looks like macOS's native one but uses *our* accent for
/// selection. The native `List(.sidebar)` ignores `.tint` and draws its
/// selection with `NSColor.controlAccentColor` (system blue) regardless,
/// so we render selection ourselves with `.listRowBackground` and a
/// rounded accent fill underneath each row.
struct Sidebar: View {
    @LumeAccent private var accent
    @Binding var selection: SidebarItem
    @AppStorage(CaptureSettings.Key.captureImages.rawValue) private var captureImages: Bool = false

    var body: some View {
        List(selection: $selection) {
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
        .tint(accent)
    }

    @ViewBuilder
    private func row(_ item: SidebarItem) -> some View {
        let isSelected = selection == item
        Label(item.rawValue, systemImage: item.symbol)
            .tag(item)
            // Override the native selection rectangle (controlAccentColor)
            // with our accent. listRowBackground replaces the row's
            // background entirely — including the selection highlight.
            .listRowBackground(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(accent.opacity(0.22))
                            .padding(.horizontal, 4)
                    } else {
                        Color.clear
                    }
                }
            )
            .foregroundStyle(isSelected ? AnyShapeStyle(accent) : AnyShapeStyle(.primary))
    }
}
