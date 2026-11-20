import SwiftUI
import AppKit

/// One choice in a segmented control, radio group or select.
public struct VoltaOption<Value: Hashable>: Identifiable {
    public let title: String
    public let value: Value
    public let symbol: String?
    public var id: Value { value }

    public init(_ title: String, value: Value, symbol: String? = nil) {
        self.title = title
        self.value = value
        self.symbol = symbol
    }
}

// MARK: Switch

/// An on/off switch. The label leads and the switch sits at the trailing edge, as in settings rows.
/// The whole row is the click target and gets a hover background; the track never changes size.
public struct VoltaSwitchStyle: ToggleStyle {
    var showsLabel: Bool
    public init(showsLabel: Bool = true) { self.showsLabel = showsLabel }
    public func makeBody(configuration: Configuration) -> some View {
        SwitchBody(configuration: configuration, showsLabel: showsLabel)
    }
}

public extension ToggleStyle where Self == VoltaSwitchStyle {
    static var voltaSwitch: VoltaSwitchStyle { VoltaSwitchStyle() }
}

private struct SwitchBody: View {
    @Environment(\.voltaPalette) private var palette
    let configuration: ToggleStyle.Configuration
    let showsLabel: Bool
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.voltaAccent) private var accent
    @State private var hovering = false

    var body: some View {
        let width = VoltaTokens.sizeSwitchWidth
        let height = VoltaTokens.sizeSwitchHeight
        let isOn = configuration.isOn
        Button { configuration.isOn.toggle() } label: {
            HStack(spacing: 10) {
                if showsLabel {
                    configuration.label
                    Spacer(minLength: 16)
                }
                ZStack(alignment: isOn ? .trailing : .leading) {
                    Capsule().fill(isOn ? accent : palette.secondary.opacity(hovering && isEnabled ? 0.32 : 0.24))
                    Circle().fill(.white)
                        .shadow(color: .black.opacity(0.22), radius: 1, y: 0.5)
                        .padding(2)
                }
                .frame(width: width, height: height)
            }
            .textSelection(.disabled)
            .padding(.horizontal, showsLabel ? 6 : 0).padding(.vertical, showsLabel ? 4 : 0)
            .background(RoundedRectangle(cornerRadius: VoltaDesign.cornerRadius)
                .fill(palette.text.opacity(showsLabel && hovering && isEnabled ? VoltaDesign.hoverOpacity : 0)))
            .contentShape(RoundedRectangle(cornerRadius: VoltaDesign.cornerRadius))
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : VoltaDesign.disabledOpacity)
        .onHover { hovering = $0 }
        .animation(VoltaDesign.animation, value: hovering)
        .animation(VoltaDesign.animation, value: isOn)
        .accessibilityRepresentation { Toggle(isOn: configuration.$isOn) { configuration.label } }
    }
}

// MARK: Segmented control

/// A row of mutually exclusive choices. The selected segment sits on a raised surface; others darken their text on hover.
public struct VoltaSegmentedControl<Value: Hashable>: View {
    @Environment(\.voltaPalette) private var palette
    let label: String
    let options: [VoltaOption<Value>]
    @Binding var selection: Value

    public init(_ label: String, options: [VoltaOption<Value>], selection: Binding<Value>) {
        self.label = label
        self.options = options
        self._selection = selection
    }

    public var body: some View {
        HStack(spacing: 2) {
            ForEach(options) { option in
                Segment(option: option, isSelected: option.value == selection) { selection = option.value }
            }
        }
        .padding(2)
        .background(palette.secondary.opacity(VoltaTokens.opacityControlFill), in: RoundedRectangle(cornerRadius: VoltaDesign.cornerRadius))
        .fixedSize()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
    }

    private struct Segment: View {
        @Environment(\.voltaPalette) private var palette
        let option: VoltaOption<Value>
        let isSelected: Bool
        let select: () -> Void
        @Environment(\.isEnabled) private var isEnabled
        @State private var hovering = false

        var body: some View {
            let radius = VoltaDesign.cornerRadius - 2
            Button(action: select) {
                Group {
                    if let symbol = option.symbol { Label(option.title, systemImage: symbol) } else { Text(option.title) }
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isSelected || (hovering && isEnabled) ? palette.text : palette.secondary)
                .padding(.horizontal, 12).padding(.vertical, 4)
                .background {
                    RoundedRectangle(cornerRadius: radius)
                        .fill(isSelected ? palette.surface : palette.text.opacity(hovering && isEnabled ? 0.05 : 0))
                        .shadow(color: .black.opacity(isSelected ? 0.12 : 0), radius: 1, y: 0.5)
                }
                .contentShape(RoundedRectangle(cornerRadius: radius))
                .textSelection(.disabled)
            }
            .buttonStyle(.plain)
            .opacity(isEnabled ? 1 : VoltaDesign.disabledOpacity)
            .onHover { hovering = $0 }
            .animation(VoltaDesign.animation, value: hovering)
            .animation(VoltaDesign.animation, value: isSelected)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
    }
}

// MARK: Radio group

/// A vertical list of mutually exclusive choices. Each row is a click target with a hover background, like a checkbox.
public struct VoltaRadioGroup<Value: Hashable>: View {
    let label: String
    let options: [VoltaOption<Value>]
    @Binding var selection: Value

    public init(_ label: String, options: [VoltaOption<Value>], selection: Binding<Value>) {
        self.label = label
        self.options = options
        self._selection = selection
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(options) { option in
                RadioRow(title: option.title, isSelected: option.value == selection) { selection = option.value }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
    }

    private struct RadioRow: View {
        @Environment(\.voltaPalette) private var palette
        let title: String
        let isSelected: Bool
        let select: () -> Void
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.voltaAccent) private var accent
        @State private var hovering = false

        var body: some View {
            let size = VoltaTokens.sizeCheckbox
            Button(action: select) {
                HStack(spacing: 8) {
                    ZStack {
                        Circle().fill(isSelected ? accent : Color.clear)
                        Circle().strokeBorder(isSelected ? accent : palette.secondary.opacity(0.6), lineWidth: 1)
                        Circle().fill(.white).frame(width: 6, height: 6).opacity(isSelected ? 1 : 0)
                    }.frame(width: size, height: size)
                    Text(title)
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
            .animation(VoltaDesign.animation, value: isSelected)
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        }
    }
}

// MARK: Select

/// A dropdown in field chrome. Clicking opens a native menu with the current choice over the control, like a pop-up button.
public struct VoltaSelect<Value: Hashable>: View {
    let label: String
    let options: [VoltaOption<Value>]
    @Binding var selection: Value
    @State private var anchor = MenuAnchor()
    @State private var hovering = false
    @Environment(\.isEnabled) private var isEnabled

    public init(_ label: String, options: [VoltaOption<Value>], selection: Binding<Value>) {
        self.label = label
        self.options = options
        self._selection = selection
    }

    public var body: some View {
        let current = options.first { $0.value == selection }
        Button(action: showMenu) {
            HStack(spacing: 8) {
                if let symbol = current?.symbol { Image(systemName: symbol).foregroundStyle(.secondary) }
                Text(current?.title ?? label).foregroundStyle(current == nil ? .secondary : .primary).lineLimit(1)
                Spacer(minLength: 8)
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary)
            }
            .textSelection(.disabled)
            .padding(.horizontal, VoltaTokens.spacingFieldHorizontal)
            .frame(maxWidth: .infinity, minHeight: VoltaDesign.fieldHeight)
            .background(MenuAnchorView(anchor: anchor))
            .voltaFieldSurface(focused: false)
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : VoltaDesign.disabledOpacity)
        .accessibilityLabel(label)
        .accessibilityValue(current?.title ?? "")
    }

    private func showMenu() {
        guard let view = anchor.view else { return }
        let menu = NSMenu()
        menu.autoenablesItems = false
        var selectedItem: NSMenuItem?
        for option in options {
            let item = ClosureMenuItem(title: option.title) { selection = option.value }
            if let symbol = option.symbol { item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) }
            if option.value == selection { item.state = .on; selectedItem = item }
            menu.addItem(item)
        }
        menu.minimumWidth = view.bounds.width
        // In the anchor's unflipped coordinates, the control's top-left is (0, height). Nudge so item text lines up with the field's.
        menu.popUp(positioning: selectedItem, at: NSPoint(x: -4, y: view.bounds.height - 6), in: view)
    }
}

/// Holds the AppKit view a select pops its menu from.
final class MenuAnchor {
    weak var view: NSView?
}

private struct MenuAnchorView: NSViewRepresentable {
    let anchor: MenuAnchor
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        anchor.view = view
        return view
    }
    func updateNSView(_ view: NSView, context: Context) { anchor.view = view }
}

/// A menu item that runs a closure.
private final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: "")
        target = self
    }

    required init(coder: NSCoder) { fatalError("not used") }

    @objc private func run() { handler() }
}
