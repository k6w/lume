import Foundation
import GRDB

final class TagRepository: @unchecked Sendable {
    private let database: AppDatabase

    init(database: AppDatabase) { self.database = database }

    /// Exposes the underlying pool for `ValueObservation.values(in:)`.
    var pool: DatabasePool { database.pool }

    // MARK: live observations

    /// Every Tag row, sorted by name, observable.
    func observeAll() -> ValueObservation<ValueReducers.Fetch<[Tag]>> {
        ValueObservation.tracking { db in
            try Tag.order(Tag.Columns.name).fetchAll(db)
        }
    }

    /// Map of clipID → Set<tagID>, observable. Drives the toolbar tag
    /// filter and the detail-pane tag chips without N+1 queries.
    func observeTagsByClip() -> ValueObservation<ValueReducers.Fetch<[String: Set<String>]>> {
        ValueObservation.tracking { db -> [String: Set<String>] in
            let rows = try Row.fetchAll(db, sql: "SELECT clipID, tagID FROM clip_tag")
            var map: [String: Set<String>] = [:]
            for r in rows {
                guard let cid: String = r["clipID"], let tid: String = r["tagID"] else { continue }
                map[cid, default: []].insert(tid)
            }
            return map
        }
    }

    // MARK: tag CRUD

    func all() throws -> [Tag] {
        try database.pool.read { db in
            try Tag.order(Tag.Columns.name).fetchAll(db)
        }
    }

    @discardableResult
    func upsert(_ tag: Tag) throws -> Tag {
        try database.pool.write { db in
            var t = tag
            try t.save(db)
            return t
        }
    }

    func delete(id: String) throws {
        try database.pool.write { db in
            _ = try Tag.deleteOne(db, id: id)
            _ = try ClipTag.filter(ClipTag.Columns.tagID == id).deleteAll(db)
        }
    }

    // MARK: clip <-> tag

    func tags(forClip id: String) throws -> [Tag] {
        try database.pool.read { db in
            try Tag.fetchAll(db, sql: """
                SELECT tag.* FROM tag
                JOIN clip_tag ON clip_tag.tagID = tag.id
                WHERE clip_tag.clipID = ?
                ORDER BY tag.name
            """, arguments: [id])
        }
    }

    func clipIDs(forTag tagID: String) throws -> [String] {
        try database.pool.read { db in
            try String.fetchAll(db, sql: """
                SELECT clipID FROM clip_tag WHERE tagID = ?
            """, arguments: [tagID])
        }
    }

    func add(tagID: String, toClip clipID: String) throws {
        try database.pool.write { db in
            try db.execute(sql: """
                INSERT OR IGNORE INTO clip_tag(clipID, tagID) VALUES (?, ?)
            """, arguments: [clipID, tagID])
        }
    }

    func remove(tagID: String, fromClip clipID: String) throws {
        try database.pool.write { db in
            try db.execute(sql: """
                DELETE FROM clip_tag WHERE clipID = ? AND tagID = ?
            """, arguments: [clipID, tagID])
        }
    }

    // MARK: counts

    func tagCounts() throws -> [(Tag, Int)] {
        try database.pool.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT tag.id AS id, tag.name AS name, tag.colorHex AS colorHex,
                       tag.icon AS icon, COUNT(clip_tag.clipID) AS n
                FROM tag LEFT JOIN clip_tag ON clip_tag.tagID = tag.id
                GROUP BY tag.id ORDER BY tag.name
            """)
            return rows.compactMap { r in
                guard let id: String = r["id"], let name: String = r["name"] else { return nil }
                let color: String? = r["colorHex"]
                let icon: String? = r["icon"]
                let n: Int = r["n"] ?? 0
                return (Tag(id: id, name: name, colorHex: color, icon: icon), n)
            }
        }
    }
}
