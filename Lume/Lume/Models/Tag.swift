import Foundation
import GRDB

struct Tag: Identifiable, Codable, Hashable, Sendable, FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "tag"

    var id: String
    var name: String
    var colorHex: String?

    enum Columns: String, ColumnExpression { case id, name, colorHex }
}

struct ClipTag: Codable, Hashable, Sendable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "clip_tag"
    var clipID: String
    var tagID: String
    enum Columns: String, ColumnExpression { case clipID, tagID }
}
