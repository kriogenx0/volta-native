import SwiftUI

/// Text buttons share one custom look instead of the system bezel: fixed-size border, hover and press feedback in 150ms.
struct VoltaButtonBody: View {
    enum Kind { case standard, prominent, link }
    let configuration: ButtonStyle.Configuration
    let kind: Kind
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.voltaAccent) private var accent
    @Environment(\.voltaPalette) private var palette
    @State private var hovering = false

    private var destructive: Bool { configuration.role == .destructive }
    private var tint: Color { destructive ? .red : accent }

    var body: some View {
        let active = hovering && isEnabled
        configuration.label
            .font(.system(size: 13, weight: kind == .prominent ? .semibold : .medium))
            .textSelection(.disabled)
            .foregroundStyle(foreground)
            .padding(.horizontal, kind == .link ? 2 : VoltaTokens.spacingControlHorizontal)
            .padding(.vertical, kind == .link ? 1 : VoltaTokens.spacingControlVertical)
            .background {
                if kind != .link {
                    RoundedRectangle(cornerRadius: VoltaDesign.cornerRadius).fill(fill(active))
                }
            }
            .overlay {
                if kind == .standard {
                    RoundedRectangle(cornerRadius: VoltaDesign.cornerRadius)
                        .strokeBorder(palette.secondary.opacity(active ? 0.5 : 0.28), lineWidth: 1)
                }
            }
            .opacity(isEnabled ? (kind == .link && active ? 0.75 : 1) : VoltaDesign.disabledOpacity)
            .contentShape(RoundedRectangle(cornerRadius: VoltaDesign.cornerRadius))
            .onHover { hovering = $0 }
            .animation(VoltaDesign.animation, value: hovering)
            .animation(VoltaDesign.animation, value: configuration.isPressed)
    }

    private var foreground: Color {
        switch kind {
        case .prominent: return .white
        case .link: return tint
        case .standard: return destructive ? .red : palette.text
        }
    }

    private func fill(_ active: Bool) -> Color {
        let pressed = configuration.isPressed
        switch kind {
        case .prominent: return tint.opacity(pressed ? 0.7 : active ? 0.88 : 1)
        default:
            return palette.secondary.opacity(pressed ? VoltaTokens.opacityControlFillPressed
                : active ? VoltaTokens.opacityControlFillHover : VoltaTokens.opacityControlFill)
        }
    }
}

/// The standard bordered text button.
public struct VoltaButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View { VoltaButtonBody(configuration: configuration, kind: .standard) }
}

/// The filled accent button for the main action in a view.
public struct VoltaProminentButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View { VoltaButtonBody(configuration: configuration, kind: .prominent) }
}

/// A text-only accent button that reads as a link.
public struct VoltaLinkButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View { VoltaButtonBody(configuration: configuration, kind: .link) }
}

/// For icon buttons: no bezel, an outline on hover and a fill on press.
public struct VoltaHoverButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View { HoverButtonBody(configuration: configuration) }
}

private struct HoverButtonBody: View {
    let configuration: ButtonStyleConfiguration
    @Environment(\.voltaPalette) private var palette

    var body: some View {
        configuration.label
            .textSelection(.disabled)
            .contentShape(RoundedRectangle(cornerRadius: VoltaDesign.cornerRadius))
            .background {
                RoundedRectangle(cornerRadius: VoltaDesign.cornerRadius)
                    .fill(palette.text.opacity(configuration.isPressed ? 0.10 : 0))
            }
            .voltaInteractiveHover()
    }
}

public extension ButtonStyle where Self == VoltaButtonStyle {
    static var volta: VoltaButtonStyle { VoltaButtonStyle() }
}

public extension ButtonStyle where Self == VoltaProminentButtonStyle {
    static var voltaProminent: VoltaProminentButtonStyle { VoltaProminentButtonStyle() }
}

public extension ButtonStyle where Self == VoltaLinkButtonStyle {
    static var voltaLink: VoltaLinkButtonStyle { VoltaLinkButtonStyle() }
}

public extension ButtonStyle where Self == VoltaHoverButtonStyle {
    static var voltaHover: VoltaHoverButtonStyle { VoltaHoverButtonStyle() }
}
