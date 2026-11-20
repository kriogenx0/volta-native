import SwiftUI
import AppKit

/// Design values in SwiftUI types. The raw numbers live in `VoltaTokens`, generated from tokens/tokens.json.
public enum VoltaDesign {
    public static let animation = Animation.easeOut(duration: VoltaTokens.motionDuration)
    public static let cornerRadius = VoltaTokens.radiusControl
    public static let fieldHeight = VoltaTokens.sizeFieldHeight
    public static let boundaryOpacity = VoltaTokens.opacityBoundary
    public static let hoverOpacity = VoltaTokens.opacityHover
    public static let dividerOpacity = VoltaTokens.opacityDivider
    public static let disabledOpacity = VoltaTokens.opacityDisabled
}

public extension Color {
    /// The default Volta accent. Read `@Environment(\.voltaAccent)` in components so apps and views can override it.
    static let voltaAccent = Color(red: VoltaTokens.colorAccentRed, green: VoltaTokens.colorAccentGreen, blue: VoltaTokens.colorAccentBlue)
    /// The system window background. Inside `.voltaTheme(_:)`, read `@Environment(\.voltaPalette).canvas` or use `VoltaCanvas()` instead.
    static let voltaCanvas = Color(nsColor: .textBackgroundColor)
}

private struct VoltaAccentKey: EnvironmentKey {
    static let defaultValue = Color.voltaAccent
}

public extension EnvironmentValues {
    /// The accent used by Volta controls. Global default from tokens, overridden per app or per view.
    var voltaAccent: Color {
        get { self[VoltaAccentKey.self] }
        set { self[VoltaAccentKey.self] = newValue }
    }
}

public extension View {
    /// Sets the Volta accent for this view and everything inside it.
    func voltaAccent(_ color: Color) -> some View { environment(\.voltaAccent, color) }

    /// Volta button and checkbox looks for app content. Apply per column, never around the window toolbar,
    /// so system controls such as the sidebar toggle keep their native style.
    func voltaControls() -> some View { buttonStyle(VoltaButtonStyle()).toggleStyle(VoltaCheckboxStyle()) }

    /// A 1pt outline that appears on hover, for clickable things with no border of their own.
    func voltaInteractiveHover() -> some View { modifier(InteractiveHover()) }

    /// A thin divider at the shared opacity.
    func voltaDivider() -> some View { overlay(alignment: .bottom) { VoltaDivider() } }
}

/// A divider at the shared opacity.
public struct VoltaDivider: View {
    public init() {}
    public var body: some View { Divider().opacity(VoltaDesign.dividerOpacity) }
}

struct InteractiveHover: ViewModifier {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.voltaPalette) private var palette
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .overlay {
                RoundedRectangle(cornerRadius: VoltaDesign.cornerRadius)
                    .strokeBorder(palette.text.opacity(isHovered && isEnabled ? VoltaDesign.hoverOpacity : 0), lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .onHover { isHovered = $0 }
            .animation(VoltaDesign.animation, value: isHovered)
    }
}
