import SwiftUI

/// Lets a person pick the appearance and colours of a `VoltaTheme`.
///
/// Bind it to the theme the app applies with `.voltaTheme(_:)`, and save it with `theme.save()` when it changes.
/// Canvas, surface and text start on the appearance's own colours; picking one makes it custom, and Reset
/// returns everything to `VoltaTheme.standard`.
public struct VoltaThemePicker: View {
    @Binding var theme: VoltaTheme
    @Environment(\.colorScheme) private var scheme
    @Environment(\.voltaPalette) private var palette

    public init(theme: Binding<VoltaTheme>) { self._theme = theme }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VoltaSectionLabel("APPEARANCE")
            Picker("Appearance", selection: $theme.appearance) {
                ForEach(VoltaTheme.Appearance.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            VoltaSectionLabel("COLORS")
            colorRow("Accent", value: Binding(get: { theme.accent }, set: { theme.accent = $0 }))
            colorRow("Background", value: custom(\.canvas, fallback: { $0.canvas }))
            colorRow("Surface", value: custom(\.surface, fallback: { $0.surface }))
            colorRow("Text", value: custom(\.text, fallback: { $0.text }))

            HStack {
                Spacer()
                Button("Reset") { theme = .standard }
                    .buttonStyle(VoltaButtonStyle())
                    .disabled(theme == .standard)
                    .help("Use the default appearance and colours")
            }
        }
    }

    private func colorRow(_ title: String, value: Binding<VoltaRGB>) -> some View {
        ColorPicker(selection: Binding(get: { value.wrappedValue.color },
                                       set: { if let rgb = VoltaRGB($0) { value.wrappedValue = rgb } }),
                    supportsOpacity: false) {
            Text(title).foregroundStyle(palette.text)
        }
    }

    /// A binding to an optional custom colour that shows the appearance's own colour while unset.
    private func custom(_ key: WritableKeyPath<VoltaTheme, VoltaRGB?>,
                        fallback: @escaping (VoltaPalette.RGBSet) -> VoltaRGB) -> Binding<VoltaRGB> {
        Binding(
            get: {
                let dark = (theme.colorScheme ?? scheme) == .dark
                return theme[keyPath: key] ?? fallback(dark ? VoltaPalette.darkRGB : VoltaPalette.lightRGB)
            },
            set: { theme[keyPath: key] = $0 }
        )
    }
}
