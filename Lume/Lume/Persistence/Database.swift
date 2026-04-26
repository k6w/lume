import Foundation
import GRDB

/// Wraps a GRDB `DatabasePool` (1 writer, N readers) — never `DatabaseQueue`,
/// so reads from the popover don't queue behind writes from the watcher.
final class AppDatabase: @unchecked Sendable {
    let pool: DatabasePool

    /// Production database in the app's Application Support directory.
    static func shared() throws -> AppDatabase {
        let url = try storeURL()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        var config = Configuration()
        config.maximumReaderCount = 4
        config.qos = .userInitiated
        // Treat busy as a soft error and retry rather than crash.
        config.busyMode = .timeout(2.0)
        let pool = try DatabasePool(path: url.path, configuration: config)
        let db = AppDatabase(pool: pool, tmpFile: nil)
        try Migrations.register().migrate(pool)
        return db
    }

    /// Per-test database: a unique tmp file (DatabasePool needs WAL, which
    /// SQLite refuses on `:memory:`). The file is auto-deleted when the
    /// `AppDatabase` is deinitialised.
    static func inMemory() throws -> AppDatabase {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("lume-test-\(UUID().uuidString).sqlite")
        var config = Configuration()
        config.maximumReaderCount = 4
        config.qos = .userInitiated
        let pool = try DatabasePool(path: url.path, configuration: config)
        let db = AppDatabase(pool: pool, tmpFile: url)
        try Migrations.register().migrate(pool)
        return db
    }

    /// Backing tmp file for in-memory databases. nil for the production store.
    private let tmpFile: URL?

    init(pool: DatabasePool, tmpFile: URL?) {
        self.pool = pool
        self.tmpFile = tmpFile
    }

    deinit {
        if let tmpFile {
            try? FileManager.default.removeItem(at: tmpFile)
            // Also clean up the WAL/SHM siblings.
            for ext in ["-wal", "-shm"] {
                try? FileManager.default.removeItem(
                    at: tmpFile.appendingPathExtension(ext.dropFirst().description)
                )
            }
        }
    }

    private static func storeURL() throws -> URL {
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        )
        return appSupport
            .appendingPathComponent("Lume", isDirectory: true)
            .appendingPathComponent("lume.sqlite")
    }
}
