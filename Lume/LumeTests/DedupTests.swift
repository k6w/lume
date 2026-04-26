import XCTest
@testable import Lume

final class DedupTests: XCTestCase {
    func testRepeatedCopiesCollapseToOneRow() throws {
        let db = try AppDatabase.inMemory()
        let repo = ClipRepository(database: db)
        let clip = Clip.text("ditto", sourceBundleID: nil)
        try repo.upsert(clip)
        try repo.upsert(clip)
        try repo.upsert(clip)
        let rows = try repo.recent()
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.hitCount, 3)
    }

    func testDifferentContentIsNotDedup() throws {
        let db = try AppDatabase.inMemory()
        let repo = ClipRepository(database: db)
        try repo.upsert(.text("a", sourceBundleID: nil))
        try repo.upsert(.text("b", sourceBundleID: nil))
        XCTAssertEqual(try repo.recent().count, 2)
    }

    func testHashIsStableAcrossInstances() {
        let h1 = ContentHasher.hash(kind: .text, payload: Data("same".utf8))
        let h2 = ContentHasher.hash(kind: .text, payload: Data("same".utf8))
        XCTAssertEqual(h1, h2)
        XCTAssertEqual(h1.count, 64)
    }
}
