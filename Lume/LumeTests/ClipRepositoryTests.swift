import XCTest
@testable import Lume

final class ClipRepositoryTests: XCTestCase {
    func testInsertAndFetch() throws {
        let db = try AppDatabase.inMemory()
        let repo = ClipRepository(database: db)
        let clip = Clip.text("hello world", sourceBundleID: "com.test")
        try repo.upsert(clip)
        let recent = try repo.recent()
        XCTAssertEqual(recent.count, 1)
        XCTAssertEqual(recent.first?.plainText, "hello world")
    }

    func testPinSurvivesPurge() throws {
        let db = try AppDatabase.inMemory()
        let repo = ClipRepository(database: db)
        var clip = Clip.text("forever", sourceBundleID: nil)
        clip.lastSeenAt = Date(timeIntervalSinceNow: -100 * 86_400)
        try repo.upsert(clip)
        try repo.setPinned(true, id: clip.id)
        let removed = try repo.purge(olderThan: Date())
        XCTAssertEqual(removed, 0, "pinned clips must survive purge")
        XCTAssertEqual(try repo.recent().count, 1)
    }

    func testDeleteAlsoTombstones() throws {
        let db = try AppDatabase.inMemory()
        let repo = ClipRepository(database: db)
        let clip = Clip.text("bye", sourceBundleID: nil)
        try repo.upsert(clip)
        try repo.delete(id: clip.id)
        try db.pool.read { conn in
            let pending = try Int.fetchOne(conn,
                sql: "SELECT pendingOp FROM sync_state WHERE clipID = ?",
                arguments: [clip.id])
            XCTAssertEqual(pending, 2)
        }
    }
}
