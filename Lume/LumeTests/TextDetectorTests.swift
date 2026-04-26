import XCTest
@testable import Lume

final class TextDetectorTests: XCTestCase {
    func testURLDetection() {
        XCTAssertTrue(TextDetector.containsURL("see https://lume.app for details"))
        XCTAssertTrue(TextDetector.containsURL("https://example.com"))
        XCTAssertFalse(TextDetector.containsURL("just some prose with no link in it."))
        XCTAssertNotNil(TextDetector.firstURL(in: "open https://example.com please"))
    }

    func testEmailDetection() {
        XCTAssertTrue(TextDetector.containsEmail("hi me@example.com — say hello"))
        XCTAssertEqual(TextDetector.firstEmail(in: "ping a.b+c@x-y.org now"), "a.b+c@x-y.org")
        XCTAssertFalse(TextDetector.containsEmail("not an email at all"))
    }

    func testTransformLowercase() {
        XCTAssertEqual(TextDetector.Transform.lowercase.apply(to: "Hello"), "hello")
    }

    func testTransformPrettyJSON() {
        let in1 = "{\"b\":2,\"a\":1}"
        let out = TextDetector.Transform.prettyJSON.apply(to: in1)
        XCTAssertNotNil(out)
        XCTAssertTrue(out!.contains("\"a\""))
        XCTAssertTrue(out!.contains("\"b\""))
        XCTAssertTrue(out!.contains("\n"))
    }

    func testTransformBase64Decode() {
        XCTAssertEqual(TextDetector.Transform.base64Decode.apply(to: "aGVsbG8="), "hello")
        XCTAssertNil(TextDetector.Transform.base64Decode.apply(to: "not base64!!"))
    }

    func testTransformAppliesGuards() {
        XCTAssertFalse(TextDetector.Transform.prettyJSON.applies(to: "hello"))
        XCTAssertTrue(TextDetector.Transform.prettyJSON.applies(to: "{ \"x\": 1 }"))
        XCTAssertFalse(TextDetector.Transform.urlDecode.applies(to: "no percents here"))
        XCTAssertTrue(TextDetector.Transform.urlDecode.applies(to: "hello%20world"))
    }

    func testWordAndLineCount() {
        XCTAssertEqual(TextDetector.wordCount("the quick brown fox"), 4)
        XCTAssertEqual(TextDetector.lineCount("a\nb\nc"), 3)
        XCTAssertEqual(TextDetector.lineCount("single"), 1)
    }
}
