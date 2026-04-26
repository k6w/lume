import Foundation
import GRDB

/// FTS5-backed search over the `clip` table.
///
/// Returns results ordered by FTS rank, then by `lastSeenAt` desc as a
/// tiebreaker (so freshness wins among equally-matched rows).
final class FullTextSearch: @unchecked Sendable {
    private let database: AppDatabase

    init(database: AppDatabase) { self.database = database }

    func search(_ query: String, limit: Int = 100, kind: ClipKind? = nil) throws -> [Clip] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let ftsQuery = Self.tokenize(trimmed)

        return try database.pool.read { db in
            var sql = """
                SELECT clip.* FROM clip
                JOIN clip_fts ON clip_fts.rowid = clip.rowid
                WHERE clip_fts MATCH ?
            """
            var args: [DatabaseValueConvertible] = [ftsQuery]
            if let kind {
                sql += " AND clip.kind = ?"
                args.append(kind.rawValue)
            }
            sql += " ORDER BY rank, clip.lastSeenAt DESC LIMIT ?"
            args.append(limit)
            return try Clip.fetchAll(db, sql: sql, arguments: StatementArguments(args))
        }
    }

    /// Turns a free-text query into a safe FTS5 prefix query. Splits on
    /// whitespace, escapes quotes, and appends `*` to each term so partial
    /// matches work as the user types.
    private static func tokenize(_ raw: String) -> String {
        raw.split(whereSeparator: \.isWhitespace)
            .map { token -> String in
                let cleaned = token.replacingOccurrences(of: "\"", with: "")
                return "\"\(cleaned)\"*"
            }
            .joined(separator: " ")
    }
}
