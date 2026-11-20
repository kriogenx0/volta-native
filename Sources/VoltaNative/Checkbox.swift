import SwiftUI

/// Checkbox with a hover background. The box and padding are fixed so nothing shifts on hover.
public struct VoltaCheckboxStyle: ToggleStyle {
    var showsLabel: Bool
    public init(showsLabel: Bool = true) { self.showsLabel = showsLabel }
    public func makeBody(configuration: Configuration) -> some View {
        CheckboxBody(configuration: configuration, showsLabel: showsLabel)
    }
}

public extension ToggleStyle where Self == VoltaCheckboxStyle {
    static var voltaCheckbox: VoltaCheckboxStyle { VoltaCheckboxStyle() }
}

private struct CheckboxBody: View {
    let configuration: ToggleStyle.Configuration
    let showsLabel: Bool
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.voltaAccent) private var accent
    @Environment(\.voltaPalette) private var palette
    @State private var hovering = false

    var body: some View {
        let radius = VoltaTokens.radiusCheckbox
        Button { configuration.isOn.toggle() } label: {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: radius).fill(configuration.isOn ? accent : Color.clear)
                    RoundedRectangle(cornerRadius: radius).strokeBorder(configuration.isOn ? accent : palette.secondary.opacity(0.6), lineWidth: 1)
                    if configuration.isOn { Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundStyle(.white) }
                }.frame(width: VoltaTokens.sizeCheckbox, height: VoltaTokens.sizeCheckbox)
                if showsLabel { configuration.label }
            }
            .textSelection(.disabled)
            .padding(.horizontal, 6).padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: VoltaDesign.cornerRadius)
                .fill(palette.text.opacity(hovering && isEnabled ? VoltaDesign.hoverOpacity : 0)))
            .contentShape(RoundedRectangle(cornerRadius: VoltaDesign.cornerRadius))
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : VoltaDesign.disabledOpacity)
        .onHover { hovering = $0 }
        .animation(VoltaDesign.animation, value: hovering)
        .accessibilityRepresentation { Toggle(isOn: configuration.$isOn) { configuration.label } }
    }
}
