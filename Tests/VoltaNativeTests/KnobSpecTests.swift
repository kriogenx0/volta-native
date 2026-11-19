import XCTest
@testable import VoltaNative

final class KnobSpecTests: XCTestCase {
    private let percent = KnobSpec(range: 0...1, defaultValue: 1, step: 0.01, displayScale: 100, unitSuffix: "%")
    private let semitones = KnobSpec(range: -24...24, defaultValue: 0, step: 1, unitSuffix: " st", showsSign: true)
    private let frequency = KnobSpec(range: 20...20_000, defaultValue: 1_000, step: 1, unitSuffix: " Hz", isLogarithmic: true)

    func testClampsToRange() {
        XCTAssertEqual(percent.clamped(1.5), 1)
        XCTAssertEqual(percent.clamped(-1), 0)
    }

    func testBipolarOnlyWhenRangeCrossesZero() {
        XCTAssertTrue(semitones.isBipolar)
        XCTAssertFalse(percent.isBipolar)
    }

    func testNormalizedRoundTrips() {
        XCTAssertEqual(semitones.normalized(0), 0.5, accuracy: 1e-9)
        XCTAssertEqual(semitones.value(atNormalized: 0.5), 0, accuracy: 1e-9)
        XCTAssertEqual(frequency.value(atNormalized: frequency.normalized(440)), 440, accuracy: 1e-6)
    }

    func testLogarithmicMidpointIsGeometricMean() {
        XCTAssertEqual(frequency.value(atNormalized: 0.5), (20.0 * 20_000).squareRoot(), accuracy: 1e-6)
    }

    func testStepping() {
        XCTAssertEqual(semitones.stepped(23, by: 3), 24)
        XCTAssertEqual(percent.stepped(0.5, by: -1), 0.49, accuracy: 1e-9)
    }

    func testFormatsWithUnitsAndSign() {
        XCTAssertEqual(percent.format(0.5), "50%")
        XCTAssertEqual(percent.format(0.505), "50.5%")
        XCTAssertEqual(semitones.format(3), "+3 st")
        XCTAssertEqual(semitones.format(0), "0 st")
        XCTAssertEqual(semitones.format(-7), "-7 st")
    }

    func testParsesTypedValues() {
        XCTAssertEqual(percent.parse("50%"), 0.5)
        XCTAssertEqual(percent.parse("50"), 0.5)
        XCTAssertEqual(percent.parse("250"), 1, "out of range clamps")
        XCTAssertNil(percent.parse("loud"), "no number leaves the value unchanged")
        XCTAssertEqual(semitones.parse("+3 st"), 3)
    }
}
