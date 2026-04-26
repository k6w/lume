import Foundation
import GRDB

/// A regex → action rule. Evaluated by the v0.3 RuleEngine.
struct Rule: Identifiable, Codable, Hashable, Sendable, FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "rule"

    var id: String
    var name: String
    var regex: String
    /// JSON-encoded action (kind + parameters). Stored as TEXT.
    var action: String
    var enabled: Bool
    var priority: Int

    enum Columns: String, ColumnExpression {
        case id, name, regex, action, enabled, priority
    }

    enum Action: Codable, Hashable, Sendable {
        case trim
        case lowercase
        case uppercase
        case prettyJSON
        case base64Encode
        case base64Decode
        case urlEncode
        case urlDecode
        case markdownToPlain
        case replace(pattern: String, with: String)
    }
}

struct ExcludedApp: Identifiable, Codable, Hashable, Sendable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "excluded_app"
    var bundleID: String
    var addedAt: Date
    var id: String { bundleID }
    enum Columns: String, ColumnExpression { case bundleID, addedAt }
}
