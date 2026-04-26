import Foundation
import GRDB

final class SnippetRepository: @unchecked Sendable {
    private let database: AppDatabase

    init(database: AppDatabase) { self.database = database }

    func all() throws -> [Snippet] {
        try database.pool.read { db in
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
