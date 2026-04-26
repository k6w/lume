import XCTest
@testable import Lume

final class FileStalenessTests: XCTestCase {
    func testAllFilesExistTrueForRealPaths() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("lume-test-\(UUID().uuidString).txt")
        try Data("ok".utf8).write(to: tmp)
        defer { try? FileManager.default.removeItem(at: tmp) }

        var clip = Clip.text("file", sourceBundleID: nil)
        clip.kind = .file
        clip.fileURLs = tmp.path
        clip.contentHash = "stale-test-real"
        XCTAssertTrue(clip.allFilesExist)
    }

    func testAllFilesExistFalseForMissing() {
        var clip = Clip.text("file", sourceBundleID: nil)
        clip.kind = .file
        clip.fileURLs = "/this/path/definitely/does/not/exist/\(UUID().uuidString)"
        XCTAssertFalse(clip.allFilesExist)
    }
}
