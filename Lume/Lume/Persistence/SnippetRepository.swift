import Foundation
import GRDB

final class SnippetRepository: @unchecked Sendable {
    private let database: AppDatabase

    init(database: AppDatabase) { self.database = database }

    /// Exposes the underlying pool for `ValueObservation.values(in:)`.
    var pool: GRDB.DatabasePool { database.pool }

    func all() throws -> [Snippet] {
        try database.pool.read { db in
            try Snippet.order(Snippet.Columns.updatedAt.desc).fetchAll(db)
        }
    }

    /// Live observation that fires whenever the snippet table changes.
    func observeAll() -> ValueObservation<ValueReducers.Fetch<[Snippet]>> {
        ValueObservation.tracking { db in
            try Snippet.order(Snippet.Columns.updatedAt.desc).fetchAll(db)
        }
    }

    @discardableResult
    func save(_ snippet: Snippet) throws -> Snippet {
        try database.pool.write { db in
            var s = snippet
            s.updatedAt = Date()
            try s.save(db)
            return s
        }
    }

    func delete(id: String) throws {
        try database.pool.write { db in _ = try Snippet.deleteOne(db, id: id) }
    }
}
