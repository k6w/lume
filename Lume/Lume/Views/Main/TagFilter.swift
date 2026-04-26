import Foundation

/// Three-state tag filter: all, untagged-only, or a specific tag id.
/// Lives on MainWindow so the toolbar picker and the HistoryBrowser
/// share a single source of truth.
enum TagFilter: Hashable {
    case all
    case untagged
    case tagID(String)
}
