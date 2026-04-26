import XCTest
@testable import Lume

final class FullTextSearchTests: XCTestCase {
    func testFindsByTokenPrefix() throws {
        let db = try AppDatabase.inMemory()
        let repo = ClipRepository(database: db)
        let fts = FullTextSearch(database: db)
        try repo.upsert(.text("the quick brown fox", sourceBundleID: nil))
        try repo.upsert(.text("lazy dog over the wall", sourceBundleID: nil))
        try repo.upsert(.text("apple pie", sourceBundleID: nil))

        let r1 = try fts.search("quic")
        XCTAssertEqual(r1.count, 1)
        XCTAssertTrue(r1.first?.plainText?.contains("quick") == true)

        let r2 = try fts.search("the")
        XCTAssertEqual(r2.count, 2)
    }
}
