import XCTest
@testable import Lume

final class SnippetExpanderTests: XCTestCase {
    func testNoVariablesPassThrough() {
        XCTAssertEqual(SnippetExpander.expand("no variables here"), "no variables here")
    }

    func testDateVariableReplaced() {
        let out = SnippetExpander.expand("today: {{date}}")
        XCTAssertFalse(out.contains("{{date}}"))
        XCTAssertTrue(out.hasPrefix("today: "))
    }

    func testTimeVariableReplaced() {
        let out = SnippetExpander.expand("now: {{time}}")
        XCTAssertFalse(out.contains("{{time}}"))
    }
}
