import XCTest
@testable import Lume

final class SensitivityDetectorTests: XCTestCase {
    func testHighEntropyStringIsSensitive() {
        let det = SensitivityDetector()
        let clip = Clip.text("xK7!aR2$bV9@nL3#qP8", sourceBundleID: nil)
        XCTAssertTrue(det.isLikelySensitive(clip))
    }

    func testShortStringIsNotSensitive() {
        let det = SensitivityDetector()
        let clip = Clip.text("hi", sourceBundleID: nil)
        XCTAssertFalse(det.isLikelySensitive(clip))
    }

    func testKnownVaultAlwaysSensitive() {
        let det = SensitivityDetector()
        let clip = Clip.text("anything", sourceBundleID: "com.bitwarden.desktop")
        XCTAssertTrue(det.isLikelySensitive(clip))
    }

    func testProseIsNotSensitive() {
        let det = SensitivityDetector()
        let clip = Clip.text("the quick brown fox jumps over", sourceBundleID: nil)
        XCTAssertFalse(det.isLikelySensitive(clip))
    }
}
