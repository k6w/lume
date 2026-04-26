import XCTest
@testable import Lume

final class PerKindRetentionTests: XCTestCase {
    func testCutoffsHonourKind() throws {
        let db = try AppDatabase.inMemory()
        let repo = ClipRepository(database: db)

        // 1 image, 1 file, 1 text — each lastSeenAt 5 days ago.
        let now = Date()
        let fiveDaysAgo = now.addingTimeInterval(-5 * 86_400)

        var image = Clip.text("img-stand-in", sourceBundleID: nil)
        image.kind = .image
        image.lastSeenAt = fiveDaysAgo
        image.contentHash = "img-hash"
        try repo.upsert(image)

        var file = Clip.text("/tmp/foo.txt", sourceBundleID: nil)
        file.kind = .file
        file.lastSeenAt = fiveDaysAgo
        file.contentHash = "file-hash"
        try repo.upsert(file)

        var text = Clip.text("hello", sourceBundleID: nil)
        text.lastSeenAt = fiveDaysAgo
        try repo.upsert(text)

        // Cutoffs: image kept only ≤ 3 days; file ≤ 30 days; text ≤ 30 days.
        let cutoffs: [ClipKind: Date] = [
            .image: now.addingTimeInterval(-3 * 86_400),
            .file:  now.addingTimeInterval(-30 * 86_400),
            .text:  now.addingTimeInterval(-30 * 86_400)
        ]
        let removed = try repo.purge(perKindCutoffs: cutoffs)
        XCTAssertEqual(removed, 1, "only the image should be purged")
        let remainingKinds = (try repo.recent()).map(\.kind)
        XCTAssertTrue(remainingKinds.contains(.file))
        XCTAssertTrue(remainingKinds.contains(.text))
        XCTAssertFalse(remainingKinds.contains(.image))
    }
}
