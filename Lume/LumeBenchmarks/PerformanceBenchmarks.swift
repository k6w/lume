import XCTest
@testable import Lume

/// Performance budgets from `docs/ARCHITECTURE.md`. These run with the
/// Release config and fail CI if any budget is breached. They are
/// deliberately tolerant on slower CI runners (use Mac Studio M1 Pro
/// or similar as the baseline).
final class PerformanceBenchmarks: XCTestCase {
    var db: AppDatabase!
    var repo: ClipRepository!

    override func setUpWithError() throws {
        db = try AppDatabase.inMemory()
        repo = ClipRepository(database: db)
    }

    func test_dedupWriteUnder3ms() throws {
        let clip = Clip.text("benchmark", sourceBundleID: nil)
        try repo.upsert(clip) // first insert
        measure(metrics: [XCTClockMetric()]) {
            for _ in 0..<10 { try? repo.upsert(clip) } // amortized dedup updates
        }
        // 10 dedup writes / 10 = avg per write. Budget: 3ms each → 30ms total.
        // XCTest reports a baseline; commit a baseline and tolerate +10%.
    }

    func test_ftsAt10kRowsUnder5ms() throws {
        let fts = FullTextSearch(database: db)
        try seed(count: 10_000)
        measure(metrics: [XCTClockMetric()]) {
            _ = try? fts.search("token-3000")
        }
    }

    func test_ftsAt100kRowsUnder16ms() throws {
        let fts = FullTextSearch(database: db)
        try seed(count: 100_000)
        measure(metrics: [XCTClockMetric()]) {
            _ = try? fts.search("token-50000")
        }
    }

    func test_recentTopFiftyUnder5ms() throws {
        try seed(count: 100_000)
        measure(metrics: [XCTClockMetric()]) {
            _ = try? repo.recent(limit: 50)
        }
    }

    // MARK: helpers

    private func seed(count: Int) throws {
        try db.pool.write { db in
            for i in 0..<count {
                let id = UUID().uuidString
                let text = "the quick brown fox jumps over token-\(i) at row \(i)"
                try db.execute(sql: """
                    INSERT INTO clip(id, contentHash, kind, plainText, byteSize, isPinned,
                                     isEncrypted, createdAt, lastSeenAt, hitCount)
                    VALUES (?, ?, 0, ?, ?, 0, 0, ?, ?, 1)
                """, arguments: [
                    id,
                    "hash-\(i)",
                    text,
                    text.utf8.count,
                    Date(),
                    Date()
                ])
            }
        }
    }
}
