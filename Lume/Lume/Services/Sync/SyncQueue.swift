import Foundation
import GRDB

/// Reads/writes the local-only `sync_state` table that drives the
/// CloudKit outbox. Each clip has one row tracking its server side
/// state and any pending operation.
struct SyncQueue {
    enum PendingOp: Int {
        case none   = 0
        case push   = 1
        case delete = 2
    }

    let database: AppDatabase

    func pendingPushes(limit: Int = 200) throws -> [String] {
        try database.pool.read { db in
            try String.fetchAll(db, sql: """
                SELECT clipID FROM sync_state
                WHERE pendingOp = 1
                ORDER BY lastSyncedAt ASC NULLS FIRST
                LIMIT ?
            """, arguments: [limit])
        }
    }

    func pendingDeletes(limit: Int = 200) throws -> [String] {
        try database.pool.read { db in
            try String.fetchAll(db, sql: """
                SELECT clipID FROM sync_state
                WHERE pendingOp = 2
                ORDER BY lastSyncedAt ASC NULLS FIRST
                LIMIT ?
            """, arguments: [limit])
        }
    }

    func markSynced(clipIDs: [String], recordNames: [String: String], changeTags: [String: String]) throws {
        try database.pool.write { db in
            for id in clipIDs {
                try db.execute(sql: """
                    INSERT INTO sync_state(clipID, ckRecordName, ckRecordChangeTag, pendingOp, lastSyncedAt)
                    VALUES (?, ?, ?, 0, ?)
                    ON CONFLICT(clipID) DO UPDATE SET
                      ckRecordName = excluded.ckRecordName,
                      ckRecordChangeTag = excluded.ckRecordChangeTag,
                      pendingOp = 0,
                      lastSyncedAt = excluded.lastSyncedAt
                """, arguments: [id, recordNames[id] ?? id, changeTags[id], Date()])
            }
        }
    }

    func clearTombstones(clipIDs: [String]) throws {
        try database.pool.write { db in
            for id in clipIDs {
                try db.execute(sql: "DELETE FROM sync_state WHERE clipID = ?", arguments: [id])
            }
        }
    }

    // MARK: Change token (server cursor)

    func loadChangeToken() throws -> Data? {
        try database.pool.read { db in
            try Data.fetchOne(db, sql: "SELECT value FROM meta WHERE key = 'cloudKit.changeToken'")
        }
    }

    func saveChangeToken(_ data: Data?) throws {
        try database.pool.write { db in
            if let data {
                try db.execute(sql: """
                    INSERT INTO meta(key, value) VALUES('cloudKit.changeToken', ?)
                    ON CONFLICT(key) DO UPDATE SET value = excluded.value
                """, arguments: [data])
            } else {
                try db.execute(sql: "DELETE FROM meta WHERE key = 'cloudKit.changeToken'")
            }
        }
    }
}
