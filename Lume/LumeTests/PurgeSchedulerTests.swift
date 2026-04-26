import XCTest
@testable import Lume

final class PurgeSchedulerTests: XCTestCase {
    func testPurgesOnlyOldNonPinned() throws {
        let db = try AppDatabase.inMemory()
        let repo = ClipRepository(database: db)

        var old = Clip.text("old", sourceBundleID: nil)
        old.lastSeenAt = Date(timeIntervalSinceNow: -60 * 86_400)
        try repo.upsert(old)

        var fresh = Clip.text("fresh", sourceBundleID: nil)
        try repo.upsert(fresh)

        var pinnedOld = Clip.text("pin-old", sourceBundleID: nil)
        pinnedOld.lastSeenAt = Date(timeIntervalSinceNow: -90 * 86_400)
        try repo.upsert(pinnedOld)
        try repo.setPinned(true, id: pinnedOld.id)

        let cutoff = Date(timeIntervalSinceNow: -30 * 86_400)
        let removed = try repo.purge(olderThan: cutoff)
        XCTAssertEqual(removed, 1)

        let remaining = try repo.recent().map(\.plainText)
        XCTAssertTrue(remaining.contains("fresh"))
        XCTAssertTrue(remaining.contains("pin-old"))
        XCTAssertFalse(remaining.contains("old"))
    }
}
