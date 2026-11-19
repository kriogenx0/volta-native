import SwiftUI

public extension View {
    /// A section panel: hairline border, faint fill, no shadow, 12pt padding. Not clickable, so it has no hover state.
    func voltaPanel() -> some View {
        padding(12)
            .background(Color.secondary.opacity(VoltaTokens.opacityPanelFill), in: RoundedRectangle(cornerRadius: VoltaDesign.cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: VoltaDesign.cornerRadius)
                    .strokeBorder(Color.secondary.opacity(VoltaDesign.boundaryOpacity), lineWidth: 1)
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
