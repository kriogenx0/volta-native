import SwiftUI

public extension View {
    /// A section panel: hairline border, faint fill, no shadow, 12pt padding. Not clickable, so it has no hover state.
    func voltaPanel() -> some View { modifier(PanelSurface()) }
}

private struct PanelSurface: ViewModifier {
    @Environment(\.voltaPalette) private var palette

    func body(content: Content) -> some View {
        content.padding(12)
            .background(palette.secondary.opacity(VoltaTokens.opacityPanelFill), in: RoundedRectangle(cornerRadius: VoltaDesign.cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: VoltaDesign.cornerRadius)
                    .strokeBorder(palette.secondary.opacity(VoltaDesign.boundaryOpacity), lineWidth: 1)
                    .allowsHitTesting(false)
            }
    }
}

/// A section heading inside a panel: 11pt semibold, secondary, not selectable.
public struct VoltaSectionLabel: View {
    let title: String
    public init(_ title: String) { self.title = title }
    public var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .textSelection(.disabled)
            .accessibilityAddTraits(.isHeader)
    }
}
