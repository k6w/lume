import XCTest
@testable import Lume

final class ConflictResolverTests: XCTestCase {
    func testNewerLastSeenWins() {
        let now = Date()
        var a = Clip.text("a", sourceBundleID: nil)
        a.lastSeenAt = now
        a.hitCount = 5
        var b = a
        b.lastSeenAt = now.addingTimeInterval(60)
        b.hitCount = 2
        b.isPinned = true

        let merged = ConflictResolver.merge(local: a, remote: b)
        XCTAssertEqual(merged.lastSeenAt, b.lastSeenAt)
        XCTAssertEqual(merged.hitCount, 5, "max(hitCount) wins")
        XCTAssertTrue(merged.isPinned, "pin OR")
    }

    func testEqualTimestampsKeepLocal() {
        let now = Date()
        var a = Clip.text("a", sourceBundleID: nil); a.lastSeenAt = now
        var b = a
        b.plainText = "different"
        let merged = ConflictResolver.merge(local: a, remote: b)
        XCTAssertEqual(merged.plainText, "a")
    }
}
