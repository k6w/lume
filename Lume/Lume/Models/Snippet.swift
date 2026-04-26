import Foundation
import GRDB

struct Snippet: Identifiable, Codable, Hashable, Sendable, FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "snippet"

    var id: String
    var title: String
    var body: String
    var shortcut: String?
    var kind: ClipKind
    var updatedAt: Date

    enum Columns: String, ColumnExpression {
        case id, title, body, shortcut, kind, updatedAt
    }
}
