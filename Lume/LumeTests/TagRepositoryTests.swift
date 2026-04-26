import XCTest
@testable import Lume

final class TagRepositoryTests: XCTestCase {
    func testAddRemoveCount() throws {
        let db = try AppDatabase.inMemory()
        let clips = ClipRepository(database: db)
        let tags = TagRepository(database: db)

        let c1 = Clip.text("first", sourceBundleID: nil)
        let c2 = Clip.text("second", sourceBundleID: nil)
        try clips.upsert(c1)
        try clips.upsert(c2)

        let tag = Tag(id: UUID().uuidString, name: "Important", colorHex: "#9B8CFF")
        _ = try tags.upsert(tag)

        try tags.add(tagID: tag.id, toClip: c1.id)
        try tags.add(tagID: tag.id, toClip: c2.id)
        try tags.add(tagID: tag.id, toClip: c1.id) // dedup OR IGNORE

        let counts = try tags.tagCounts()
        XCTAssertEqual(counts.count, 1)
        XCTAssertEqual(counts.first?.1, 2)

        try tags.remove(tagID: tag.id, fromClip: c1.id)
        let after = try tags.tagCounts()
        XCTAssertEqual(after.first?.1, 1)
    }

    func testDeleteTagCleansLinks() throws {
        let db = try AppDatabase.inMemory()
        let clips = ClipRepository(database: db)
        let tags = TagRepository(database: db)
        let c = Clip.text("x", sourceBundleID: nil)
        try clips.upsert(c)
        let tag = Tag(id: UUID().uuidString, name: "Tmp", colorHex: nil)
        _ = try tags.upsert(tag)
        try tags.add(tagID: tag.id, toClip: c.id)

        try tags.delete(id: tag.id)
        let after = try tags.tagCounts()
        XCTAssertEqual(after.count, 0)
    }
}
