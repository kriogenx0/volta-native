import XCTest
import SwiftUI
@testable import VoltaNative

final class ThemeTests: XCTestCase {
    func testHexRoundTrip() throws {
        let rgb = try XCTUnwrap(VoltaRGB(hex: "#1E1E1E"))
        XCTAssertEqual(rgb.hex, "#1E1E1E")
        XCTAssertEqual(VoltaRGB(hex: "ff8000")?.hex, "#FF8000")
        XCTAssertNil(VoltaRGB(hex: "#12"))
        XCTAssertNil(VoltaRGB(hex: "zzzzzz"))
    }

    func testCodableRoundTrip() throws {
        let theme = VoltaTheme(appearance: .dark, accent: VoltaRGB(red: 0.2, green: 0.4, blue: 0.6),
                               canvas: VoltaRGB(hex: "#101010"), text: VoltaRGB(hex: "#F0F0F0"))
        let data = try JSONEncoder().encode(theme)
        XCTAssertEqual(try JSONDecoder().decode(VoltaTheme.self, from: data), theme)
    }

    func testDecodingFillsMissingAndUnknownValues() throws {
        let decoded = try JSONDecoder().decode(VoltaTheme.self, from: Data(#"{"appearance":"sepia"}"#.utf8))
        XCTAssertEqual(decoded, .standard)
    }

    func testSaveAndLoad() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "VoltaThemeTests"))
        defaults.removePersistentDomain(forName: "VoltaThemeTests")
        XCTAssertEqual(VoltaTheme.load(from: defaults), .standard)
        let theme = VoltaTheme(appearance: .light, surface: VoltaRGB(hex: "#EEEEEE"))
        theme.save(to: defaults)
        XCTAssertEqual(VoltaTheme.load(from: defaults), theme)
        defaults.removePersistentDomain(forName: "VoltaThemeTests")
    }

    func testSystemAppearanceUsesSystemColors() {
        XCTAssertEqual(VoltaTheme.standard.palette(for: .dark), .system)
        XCTAssertNil(VoltaTheme.standard.colorScheme)
    }

    func testForcedAppearanceIgnoresSystemScheme() {
        let dark = VoltaTheme(appearance: .dark)
        XCTAssertEqual(dark.palette(for: .light).canvas, VoltaPalette.darkRGB.canvas.color)
        XCTAssertEqual(VoltaTheme(appearance: .light).palette(for: .dark).text, VoltaPalette.lightRGB.text.color)
    }

    func testCustomTextDerivesSecondaryFromCanvas() throws {
        let text = try XCTUnwrap(VoltaRGB(hex: "#FFFFFF"))
        let canvas = try XCTUnwrap(VoltaRGB(hex: "#000000"))
        let palette = VoltaTheme(appearance: .dark, canvas: canvas, text: text).palette(for: .dark)
        XCTAssertEqual(palette.text, text.color)
        XCTAssertEqual(palette.secondary, VoltaRGB(red: 0.6, green: 0.6, blue: 0.6).color)
    }
}
