import XCTest
import AppKit
@testable import VoltaNative

final class TokensTests: XCTestCase {
    private let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    /// Fails when tokens.json was edited without running `make tokens`.
    func testGeneratedTokensMatchJSON() throws {
        let data = try Data(contentsOf: root.appendingPathComponent("tokens/tokens.json"))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: [String: Any]])
        XCTAssertEqual(json["radius"]?["control"] as? Double, Double(VoltaTokens.radiusControl))
        XCTAssertEqual(json["size"]?["fieldHeight"] as? Double, Double(VoltaTokens.sizeFieldHeight))
        XCTAssertEqual(json["motion"]?["duration"] as? Double, VoltaTokens.motionDuration)
        let accent = try XCTUnwrap(json["color"]?["accent"] as? [String: Double])
        XCTAssertEqual(accent["red"], VoltaTokens.colorAccentRed)

        let header = try String(contentsOf: root.appendingPathComponent("include/volta_tokens.h"), encoding: .utf8)
        XCTAssertTrue(header.contains("#define VOLTA_RADIUS_CONTROL \(Double(VoltaTokens.radiusControl))"))
        XCTAssertTrue(header.contains("#define VOLTA_MOTION_DURATION \(VoltaTokens.motionDuration)"))
    }

    /// Every function in the C header has a Swift implementation with the same name.
    func testCHeaderMatchesImplementation() throws {
        let header = try String(contentsOf: root.appendingPathComponent("include/volta_native.h"), encoding: .utf8)
        let swift = try String(contentsOf: root.appendingPathComponent("Sources/VoltaNativeC/CAPI.swift"), encoding: .utf8)
        let declared = Set(header.matches(of: #/\b(volta_[a-z_]+)\(/#).map { String($0.1) })
        let implemented = Set(swift.matches(of: #/@_cdecl\("(volta_[a-z_]+)"\)/#).map { String($0.1) })
        XCTAssertFalse(declared.isEmpty)
        XCTAssertEqual(declared, implemented)
    }
}

final class FlowLayoutTests: XCTestCase {
    func testWrapsOntoNewRowWhenTooWide() {
        let sizes = Array(repeating: CGSize(width: 40, height: 20), count: 3)
        let result = VoltaFlowLayout.arrange(sizes: sizes, width: 100, spacing: 10)
        XCTAssertEqual(result.points, [CGPoint(x: 0, y: 0), CGPoint(x: 50, y: 0), CGPoint(x: 0, y: 30)])
        XCTAssertEqual(result.size, CGSize(width: 90, height: 50))
    }

    func testItemWiderThanRowStillGetsItsOwnRow() {
        let result = VoltaFlowLayout.arrange(sizes: [CGSize(width: 150, height: 10)], width: 100, spacing: 5)
        XCTAssertEqual(result.points, [.zero])
    }
}

final class RichTextBasicsTests: XCTestCase {
    func testPlainTextHasNoHTML() {
        let text = NSAttributedString(string: "Hello", attributes: RichText.baseAttributes())
        XCTAssertNil(RichText.html(from: text))
    }

    func testBoldBecomesStrong() throws {
        let text = NSMutableAttributedString(string: "Hello", attributes: RichText.baseAttributes())
        text.addAttribute(.font, value: RichText.font(.body, bold: true), range: NSRange(location: 0, length: 5))
        let html = try XCTUnwrap(RichText.html(from: text))
        XCTAssertTrue(html.contains("Hello"))
        XCTAssertTrue(html.contains("<b>") || html.contains("<strong>"), html)
    }

    func testArchiveRoundTrips() throws {
        let text = NSAttributedString(string: "Saved", attributes: RichText.baseAttributes())
        let data = try XCTUnwrap(RichText.archive(text))
        XCTAssertEqual(RichText.unarchive(data)?.string, "Saved")
    }
}

final class FeedbackTests: XCTestCase {
    func testSweepStaysInsideTrackAndReturns() {
        let period = VoltaProgressBar.sweepPeriod
        XCTAssertEqual(VoltaProgressBar.sweepOffset(at: 0), 0, accuracy: 1e-9)
        XCTAssertEqual(VoltaProgressBar.sweepOffset(at: period / 2), 1 - VoltaProgressBar.sweepLength, accuracy: 1e-9)
        XCTAssertEqual(VoltaProgressBar.sweepOffset(at: period), 0, accuracy: 1e-9)
        for step in 0...100 {
            let offset = VoltaProgressBar.sweepOffset(at: Double(step) * period / 37)
            XCTAssertGreaterThanOrEqual(offset, 0)
            XCTAssertLessThanOrEqual(offset + VoltaProgressBar.sweepLength, 1 + 1e-9)
        }
    }

    func testSpinnerBrightestArmLeadsAndOthersFade() {
        XCTAssertEqual(VoltaSpinner.armOpacity(arm: 3, step: 3), 1)
        XCTAssertGreaterThan(VoltaSpinner.armOpacity(arm: 2, step: 3), VoltaSpinner.armOpacity(arm: 1, step: 3))
        XCTAssertEqual(VoltaSpinner.armOpacity(arm: 4, step: 3), 0.15, "The arm just ahead is the dimmest")
        XCTAssertEqual(VoltaSpinner.armOpacity(arm: 11, step: 0), VoltaSpinner.armOpacity(arm: 0, step: 1))
    }

    func testToneRawValuesMatchCHeader() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let header = try String(contentsOf: root.appendingPathComponent("include/volta_native.h"), encoding: .utf8)
        for tone in VoltaTone.allCases {
            XCTAssertTrue(header.contains("VOLTA_TONE_\(String(describing: tone).uppercased()) = \(tone.rawValue)"), "\(tone)")
        }
    }
}
