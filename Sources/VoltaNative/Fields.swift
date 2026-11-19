import SwiftUI
import AppKit

public extension View {
    /// Field chrome: fixed-size border (the click mask), hover outline, accent border on focus, all in 150ms.
    func voltaFieldSurface(focused: Bool) -> some View { modifier(FieldSurface(focused: focused)) }

    /// Turns a plain `TextField` or `SecureField` into a Volta field. Tracks its own focus.
    func voltaField() -> some View { modifier(VoltaFieldStyle()) }
}

private struct FieldSurface: ViewModifier {
    let focused: Bool
    @Environment(\.voltaAccent) private var accent

    func body(content: Content) -> some View {
        content
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: VoltaDesign.cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: VoltaDesign.cornerRadius)
                    .strokeBorder(focused ? accent : Color.secondary.opacity(0.28), lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .contentShape(RoundedRectangle(cornerRadius: VoltaDesign.cornerRadius))
            .voltaInteractiveHover()
            .animation(VoltaDesign.animation, value: focused)
    }
}

/// Padding, height and surface for a single-line text field.
public struct VoltaFieldStyle: ViewModifier {
    @FocusState private var focused: Bool
    public init() {}

    public func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .focused($focused)
            .padding(.horizontal, VoltaTokens.spacingFieldHorizontal)
            .frame(maxWidth: .infinity, minHeight: VoltaDesign.fieldHeight, alignment: .leading)
            .voltaFieldSurface(focused: focused)
            .onTapGesture { focused = true }
    }
}

/// A labelled single-line text field.
public struct VoltaTextField: View {
    let title: String
    let prompt: String
    @Binding var text: String

    public init(_ title: String, text: Binding<String>, prompt: String = "") {
        self.title = title
        self._text = text
        self.prompt = prompt
    }

    public var body: some View {
        TextField(title, text: $text, prompt: Text(prompt.isEmpty ? title : prompt))
            .accessibilityLabel(title)
            .voltaField()
    }
}

/// A search field with a magnifying glass and a clear button that appears once there is text.
public struct VoltaSearchField: View {
    let placeholder: String
    @Binding var text: String
    @FocusState private var focused: Bool

    public init(_ placeholder: String = "Search", text: Binding<String>) {
        self.placeholder = placeholder
        self._text = text
    }

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary).accessibilityHidden(true)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain).focused($focused).accessibilityLabel(placeholder)
            if !text.isEmpty {
                Button { text = ""; focused = true } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                }.buttonStyle(VoltaHoverButtonStyle()).help("Clear search").accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, VoltaTokens.spacingFieldHorizontal)
        .frame(minHeight: VoltaDesign.fieldHeight)
        .voltaFieldSurface(focused: focused)
        .onTapGesture { focused = true }
    }
}
