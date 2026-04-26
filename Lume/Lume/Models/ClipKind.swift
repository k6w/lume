import Foundation

/// The kind of payload a clip carries. Stored as INTEGER so the column is
/// stable across migrations even if names change.
enum ClipKind: Int, Codable, CaseIterable, Sendable {
    case text   = 0
    case rtf    = 1
    case html   = 2
    case image  = 3
    case file   = 4
    case color  = 5
    case code   = 6

    var displayName: String {
        switch self {
        case .text:  return "Text"
        case .rtf:   return "Rich Text"
        case .html:  return "HTML"
        case .image: return "Image"
        case .file:  return "File"
        case .color: return "Color"
        case .code:  return "Code"
        }
    }

    var sfSymbol: String {
        switch self {
        case .text:  return "text.alignleft"
        case .rtf:   return "doc.richtext"
        case .html:  return "chevron.left.forwardslash.chevron.right"
        case .image: return "photo"
        case .file:  return "doc"
        case .color: return "paintpalette"
        case .code:  return "curlybraces"
        }
    }
}
