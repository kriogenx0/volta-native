import SwiftUI
import AppKit

/// An sRGB colour that can be saved (it is `Codable`) and shown as a SwiftUI `Color`.
public struct VoltaRGB: Codable, Hashable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// The sRGB components of `color`, or nil if it can't be converted (a pattern colour, say).
    public init?(_ color: Color) {
        guard let rgb = NSColor(color).usingColorSpace(.sRGB) else { return nil }
        self.init(red: Double(rgb.redComponent), green: Double(rgb.greenComponent), blue: Double(rgb.blueComponent))
    }

    /// Accepts `#RRGGBB` or `RRGGBB`.
    public init?(hex: String) {
        let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else { return nil }
        self.init(red: Double((value >> 16) & 0xff) / 255, green: Double((value >> 8) & 0xff) / 255, blue: Double(value & 0xff) / 255)
    }

    public var hex: String {
        func byte(_ v: Double) -> Int { Int((min(max(v, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", byte(red), byte(green), byte(blue))
    }

    public var color: Color { Color(.sRGB, red: red, green: green, blue: blue) }

    /// `self` drawn at `amount` (0...1) over `base`, as an opaque colour.
    public func mixed(over base: VoltaRGB, amount: Double) -> VoltaRGB {
        VoltaRGB(red: base.red + (red - base.red) * amount,
                 green: base.green + (green - base.green) * amount,
                 blue: base.blue + (blue - base.blue) * amount)
    }
}

/// The colours a person can choose, plus light or dark. Apply it with `.voltaTheme(_:)`.
///
/// - `appearance` `.system` follows macOS light and dark mode. Where the system appearance isn't
///   available (the JUCE look on a platform without it), it falls back to dark.
/// - `canvas`, `surface` and `text` are optional: nil keeps the appearance's own colour, so a
///   theme can change just the accent.
public struct VoltaTheme: Codable, Hashable, Sendable {
    public enum Appearance: String, Codable, CaseIterable, Identifiable, Sendable {
        case system, light, dark
        public var id: Self { self }
        public var title: String {
            switch self {
            case .system: return "System"
            case .light: return "Light"
            case .dark: return "Dark"
            }
        }
    }

    public var appearance: Appearance
    public var accent: VoltaRGB
    /// Window background.
    public var canvas: VoltaRGB?
    /// Fields, knob discs and menus.
    public var surface: VoltaRGB?
    /// Primary text. Secondary text and borders are derived from it.
    public var text: VoltaRGB?

    public init(appearance: Appearance = .system, accent: VoltaRGB = VoltaTheme.defaultAccent,
                canvas: VoltaRGB? = nil, surface: VoltaRGB? = nil, text: VoltaRGB? = nil) {
        self.appearance = appearance
        self.accent = accent
        self.canvas = canvas
        self.surface = surface
        self.text = text
    }

    public static let defaultAccent = VoltaRGB(red: VoltaTokens.colorAccentRed, green: VoltaTokens.colorAccentGreen, blue: VoltaTokens.colorAccentBlue)

    /// The Volta default: system appearance and the ember accent.
    public static let standard = VoltaTheme()

    public var hasCustomColors: Bool { canvas != nil || surface != nil || text != nil }

    /// The colour scheme this theme forces, or nil to follow the system.
    public var colorScheme: ColorScheme? {
        switch appearance {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    /// The colours to draw with under `scheme` (the scheme in effect when `appearance` is `.system`).
    public func palette(for scheme: ColorScheme) -> VoltaPalette {
        let dark = (colorScheme ?? scheme) == .dark
        let base = dark ? VoltaPalette.darkRGB : VoltaPalette.lightRGB

        // With no custom colours and the system appearance, keep AppKit's dynamic colours so
        // components match the rest of macOS exactly.
        if appearance == .system && !hasCustomColors {
            return .system
        }

        let canvas = self.canvas ?? base.canvas
        let surface = self.surface ?? base.surface
        let text = self.text ?? base.text
        let secondary = self.text.map { $0.mixed(over: canvas, amount: 0.6) } ?? base.secondary
        return VoltaPalette(canvas: canvas.color, surface: surface.color, text: text.color, secondary: secondary.color)
    }

    // MARK: Saving

    public static let defaultsKey = "VoltaTheme"

    /// The theme saved under `key`, or `.standard` if there is none or it can't be read.
    public static func load(from defaults: UserDefaults = .standard, key: String = defaultsKey) -> VoltaTheme {
        guard let data = defaults.data(forKey: key),
              let theme = try? JSONDecoder().decode(VoltaTheme.self, from: data) else { return .standard }
        return theme
    }

    public func save(to defaults: UserDefaults = .standard, key: String = VoltaTheme.defaultsKey) {
        if let data = try? JSONEncoder().encode(self) { defaults.set(data, forKey: key) }
    }

    // Tolerant decoding, so a theme saved by an older or newer version still loads.
    private enum CodingKeys: String, CodingKey { case appearance, accent, canvas, surface, text }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        appearance = (try? c.decodeIfPresent(Appearance.self, forKey: .appearance)) ?? .system
        accent = (try? c.decodeIfPresent(VoltaRGB.self, forKey: .accent)) ?? VoltaTheme.defaultAccent
        canvas = try? c.decodeIfPresent(VoltaRGB.self, forKey: .canvas)
        surface = try? c.decodeIfPresent(VoltaRGB.self, forKey: .surface)
        text = try? c.decodeIfPresent(VoltaRGB.self, forKey: .text)
    }
}

/// Resolved colours for drawing. Components read it from `@Environment(\.voltaPalette)`.
public struct VoltaPalette: Equatable, Sendable {
    public var canvas: Color
    public var surface: Color
    public var text: Color
    public var secondary: Color

    public init(canvas: Color, surface: Color, text: Color, secondary: Color) {
        self.canvas = canvas
        self.surface = surface
        self.text = text
        self.secondary = secondary
    }

    /// AppKit's dynamic system colours: follows light and dark by itself.
    public static let system = VoltaPalette(canvas: Color(nsColor: .textBackgroundColor),
                                            surface: Color(nsColor: .controlBackgroundColor),
                                            text: .primary, secondary: .secondary)

    struct RGBSet { let canvas, surface, text, secondary: VoltaRGB }

    static let lightRGB = RGBSet(
        canvas: VoltaRGB(red: VoltaTokens.colorLightCanvasRed, green: VoltaTokens.colorLightCanvasGreen, blue: VoltaTokens.colorLightCanvasBlue),
        surface: VoltaRGB(red: VoltaTokens.colorLightSurfaceRed, green: VoltaTokens.colorLightSurfaceGreen, blue: VoltaTokens.colorLightSurfaceBlue),
        text: VoltaRGB(red: VoltaTokens.colorLightTextRed, green: VoltaTokens.colorLightTextGreen, blue: VoltaTokens.colorLightTextBlue),
        secondary: VoltaRGB(red: VoltaTokens.colorLightSecondaryRed, green: VoltaTokens.colorLightSecondaryGreen, blue: VoltaTokens.colorLightSecondaryBlue))

    static let darkRGB = RGBSet(
        canvas: VoltaRGB(red: VoltaTokens.colorDarkCanvasRed, green: VoltaTokens.colorDarkCanvasGreen, blue: VoltaTokens.colorDarkCanvasBlue),
        surface: VoltaRGB(red: VoltaTokens.colorDarkSurfaceRed, green: VoltaTokens.colorDarkSurfaceGreen, blue: VoltaTokens.colorDarkSurfaceBlue),
        text: VoltaRGB(red: VoltaTokens.colorDarkTextRed, green: VoltaTokens.colorDarkTextGreen, blue: VoltaTokens.colorDarkTextBlue),
        secondary: VoltaRGB(red: VoltaTokens.colorDarkSecondaryRed, green: VoltaTokens.colorDarkSecondaryGreen, blue: VoltaTokens.colorDarkSecondaryBlue))
}

private struct VoltaThemeKey: EnvironmentKey {
    static let defaultValue = VoltaTheme.standard
}

private struct VoltaPaletteKey: EnvironmentKey {
    static let defaultValue = VoltaPalette.system
}

public extension EnvironmentValues {
    /// The theme set by the nearest `.voltaTheme(_:)`.
    var voltaTheme: VoltaTheme {
        get { self[VoltaThemeKey.self] }
        set { self[VoltaThemeKey.self] = newValue }
    }

    /// The colours Volta components draw with, resolved from the theme and the colour scheme.
    var voltaPalette: VoltaPalette {
        get { self[VoltaPaletteKey.self] }
        set { self[VoltaPaletteKey.self] = newValue }
    }
}

private struct VoltaThemeModifier: ViewModifier {
    let theme: VoltaTheme
    @Environment(\.colorScheme) private var systemScheme

    func body(content: Content) -> some View {
        let palette = theme.palette(for: systemScheme)
        content
            .environment(\.voltaTheme, theme)
            .environment(\.voltaPalette, palette)
            .voltaAccent(theme.accent.color)
            .tint(theme.accent.color)
            .foregroundStyle(palette.text)
            .environment(\.colorScheme, theme.colorScheme ?? systemScheme)
    }
}

public extension View {
    /// Applies a theme to this view and everything inside it: appearance, accent and custom colours.
    /// Put the theme's canvas behind your content with `.background(palette.canvas)` or `VoltaCanvas()`.
    func voltaTheme(_ theme: VoltaTheme) -> some View { modifier(VoltaThemeModifier(theme: theme)) }
}

/// Fills its space with the theme's window background.
public struct VoltaCanvas: View {
    @Environment(\.voltaPalette) private var palette
    public init() {}
    public var body: some View { palette.canvas.ignoresSafeArea() }
}
