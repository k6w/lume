import Foundation
import GRDB

/// All read/write paths for `Clip`. Dedup is enforced here, not by the
/// schema (the unique index is only a safety net).
final class ClipRepository: @unchecked Sendable {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    /// Exposed for `ValueObservation.values(in:)` streaming inside SwiftUI.
    var pool: DatabasePool { database.pool }

    // MARK: Writes

    /// Upsert a freshly captured clip. Returns the persisted row's id.
    /// On dedup hit, increments `hitCount`, advances `lastSeenAt`, marks
    /// the row pending-push for sync.
    @discardableResult
    func upsert(_ clip: Clip) throws -> String {
        try database.pool.write { db in
            if let existing = try Clip
                .filter(Clip.Columns.contentHash == clip.contentHash)
                .fetchOne(db) {
                try db.execute(sql: """
                    UPDATE clip SET lastSeenAt = ?, hitCount = hitCount + 1
                    WHERE contentHash = ?
                """, arguments: [clip.lastSeenAt, clip.contentHash])
                try Self.markPending(db: db, clipID: existing.id)
                return existing.id
            }
            var inserted = clip
            try inserted.insert(db)
            try Self.markPending(db: db, clipID: inserted.id)
            return inserted.id
        }
    }

    func delete(id: String) throws {
        try database.pool.write { db in
            _ = try Clip.deleteOne(db, id: id)
            try db.execute(sql: """
                INSERT OR REPLACE INTO sync_state(clipID, pendingOp, lastSyncedAt)
                VALUES (?, 2, NULL)
            """, arguments: [id])
        }
    }

    func setPinned(_ pinned: Bool, id: String) throws {
        try database.pool.write { db in
            // Bumping lastSeenAt on pin keeps the just-pinned clip at the
            // top of the pinned section — without this, pinning an old
            // clip looks like a no-op because the row stays buried.
            try db.execute(sql: """
                UPDATE clip SET isPinned = ?, lastSeenAt = ? WHERE id = ?
            """, arguments: [pinned ? 1 : 0, Date(), id])
            try Self.markPending(db: db, clipID: id)
        }
    }

    private static func markPending(db: Database, clipID: String) throws {
        try db.execute(sql: """
            INSERT INTO sync_state(clipID, pendingOp) VALUES (?, 1)
            ON CONFLICT(clipID) DO UPDATE SET pendingOp = 1
        """, arguments: [clipID])
    }

    // MARK: Reads

    func recent(limit: Int = 200) throws -> [Clip] {
        try database.pool.read { db in
            try Clip
                .order(Clip.Columns.isPinned.desc, Clip.Columns.lastSeenAt.desc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    /// Live observation for the popover top-N rows.
    func observeRecent(limit: Int = 50) -> ValueObservation<ValueReducers.Fetch<[Clip]>> {
        ValueObservation.tracking { db in
            try Clip
                .order(Clip.Columns.isPinned.desc, Clip.Columns.lastSeenAt.desc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    func clip(id: String) throws -> Clip? {
        try database.pool.read { db in try Clip.fetchOne(db, id: id) }
    }

    // MARK: Purge

    /// Delete every non-pinned clip whose `lastSeenAt` is older than `cutoff`.
    /// Returns the number of rows removed.
    @discardableResult
    func purge(olderThan cutoff: Date) throws -> Int {
        try database.pool.write { db in
            let count = try Clip
                .filter(Clip.Columns.isPinned == false &&
                        Clip.Columns.lastSeenAt < cutoff)
                .deleteAll(db)
            return count
        }
    }

    /// Wipe every non-pinned clip. Used by the "Clear history" button.
    @discardableResult
    func deleteAllUnpinned() throws -> Int {
        try database.pool.write { db in
            let count = try Clip.filter(Clip.Columns.isPinned == false).deleteAll(db)
            return count
        }
    }

    /// Compact the database file (SQLite VACUUM). Cheap; handy after a
    /// bulk delete so the on-disk size matches reality.
    func compact() throws {
        try database.pool.write { db in
            try db.execute(sql: "VACUUM")
        }
    }

    /// Per-kind cutoff. The dictionary maps a `ClipKind` to the oldest
    /// `lastSeenAt` it's allowed to keep; rows older than that are
    /// dropped (pinned rows always survive).
    @discardableResult
    func purge(perKindCutoffs cutoffs: [ClipKind: Date]) throws -> Int {
        try database.pool.write { db in
            var removed = 0
            for (kind, cutoff) in cutoffs {
                removed += try Clip
                    .filter(Clip.Columns.isPinned == false &&
                            Clip.Columns.kind == kind.rawValue &&
                            Clip.Columns.lastSeenAt < cutoff)
                    .deleteAll(db)
            }
            return removed
        }
    }
}
