import Foundation

/// User-tunable layout of clip rows in the menu-bar popover.
enum PopoverStyle: String, CaseIterable, Identifiable {
    case `default` = "default"
    case minimal   = "minimal"

    static let storageKey = "lume.popoverStyle"
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .default: return "Default"
        case .minimal: return "Minimal"
        }
    }

    var blurb: String {
        switch self {
        case .default:
            return "Two-line rows with a kind chip, preview, source app, and time. Best when you scan history visually."
        case .minimal:
            return "Single-line rows with the content on the left and the source app icon on the right. Meta and pin appear on hover. Best when you want maximum density."
        }
    }
}
