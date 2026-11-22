import AppKit
import SwiftUI

/// A knob for one continuous parameter, in the Volta style (ported from Dicer's `KnobView`).
///
/// - Drag up or down to change it; hold Option for fine control.
/// - Use the arrow keys when it has focus. Scrolling over it scrolls the page unless
///   `scrollAdjusts` is on.
/// - Double-click the knob to reset to the default.
/// - Click the value to type an exact one (Return or clicking away commits, Escape cancels).
public struct VoltaKnob: View {
    let label: String
    let spec: KnobSpec
    @Binding var value: Double
    /// Shown instead of the value while disabled (e.g. "Host" when the tempo follows the host).
    var disabledText: String?
    /// Whether the scroll wheel changes the value while the pointer is over the knob.
    /// Off by default, so scrolling a view over a knob scrolls the view instead of moving the knob.
    var scrollAdjusts: Bool

    public init(_ label: String, spec: KnobSpec, value: Binding<Double>, disabledText: String? = nil,
                scrollAdjusts: Bool = false) {
        self.label = label
        self.spec = spec
        self._value = value
        self.disabledText = disabledText
        self.scrollAdjusts = scrollAdjusts
    }

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.voltaAccent) private var accent
    @Environment(\.voltaPalette) private var palette
    @State private var lastDragY: CGFloat?
    @State private var isHovering = false
    @State private var scrollMonitor: Any?
    @State private var isEditing = false
    @State private var editText = ""
    @FocusState private var isTextFieldFocused: Bool

    public static let diameter = VoltaTokens.sizeKnob
    private static let trackWidth = VoltaTokens.sizeKnobTrack
    private static let sweep = 0.75  // fraction of a full turn the arc covers
    private static let dragPointsForFullRange: CGFloat = 200
    private static let fineFactor = 0.1
    private static let valueFont = Font.system(size: 11, weight: .medium).monospacedDigit()

    public var body: some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .textSelection(.disabled)
            dial
            valueField
        }
        .frame(width: 76)
        .opacity(isEnabled ? 1 : VoltaDesign.disabledOpacity)
        .onAppear(perform: installScrollMonitor)
        .onDisappear(perform: removeScrollMonitor)
    }

    // MARK: Dial

    private var normalized: Double { spec.normalized(value) }

    private var dial: some View {
        let active = isHovering && isEnabled
        return ZStack {
            arc(from: 0, to: Self.sweep)
                .stroke(palette.secondary.opacity(active ? VoltaDesign.dividerOpacity : VoltaTokens.opacityControlFillHover),
                        style: StrokeStyle(lineWidth: Self.trackWidth, lineCap: .round))
            valueArc
                .stroke(accent, style: StrokeStyle(lineWidth: Self.trackWidth, lineCap: .round))
            Circle()
                .fill(palette.surface)
                .overlay(Circle().strokeBorder(palette.secondary.opacity(VoltaDesign.boundaryOpacity * 2), lineWidth: 1))
                .padding(8)
            Capsule()
                .fill(palette.text.opacity(0.8))
                .frame(width: 2, height: Self.diameter * 0.18)
                .offset(y: -Self.diameter * 0.2)
                .rotationEffect(.degrees(-135 + 270 * normalized))
        }
        .frame(width: Self.diameter, height: Self.diameter)
        .contentShape(Circle())
        .animation(VoltaDesign.animation, value: active)
        .gesture(dragGesture)
        .simultaneousGesture(TapGesture(count: 2).onEnded { setValue(spec.defaultValue) })
        .onHover { isHovering = $0 }
        .focusable()
        .onKeyPress(.upArrow) { nudge(by: 1); return .handled }
        .onKeyPress(.rightArrow) { nudge(by: 1); return .handled }
        .onKeyPress(.downArrow) { nudge(by: -1); return .handled }
        .onKeyPress(.leftArrow) { nudge(by: -1); return .handled }
        .help("Drag to change, Option-drag for fine control, double-click to reset")
        .accessibilityElement()
        .accessibilityLabel(label)
        .accessibilityValue(displayedValue)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: nudge(by: 1)
            case .decrement: nudge(by: -1)
            @unknown default: break
            }
        }
    }

    /// Bipolar knobs fill from the center; others fill from the minimum.
    private var valueArc: some Shape {
        let position = normalized * Self.sweep
        let origin = spec.isBipolar ? Self.sweep / 2 : 0
        return arc(from: min(origin, position), to: max(origin, position))
    }

    /// A segment of the knob's track. 0 is the lower-left end, `sweep` the lower-right.
    private func arc(from start: Double, to end: Double) -> some Shape {
        Circle()
            .trim(from: start, to: end)
            .rotation(.degrees(135))
    }

    // MARK: Input

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { drag in
                let y = drag.location.y
                defer { lastDragY = y }
                guard let lastY = lastDragY else { return }
                let fine = NSEvent.modifierFlags.contains(.option) ? Self.fineFactor : 1
                let travel = Double(lastY - y) / Self.dragPointsForFullRange * fine
                setValue(spec.value(atNormalized: normalized + travel))
            }
            .onEnded { _ in lastDragY = nil }
    }

    private func nudge(by steps: Double) {
        let fine = NSEvent.modifierFlags.contains(.option) ? Self.fineFactor : 1
        setValue(spec.stepped(value, by: steps * fine))
    }

    private func setValue(_ newValue: Double) {
        let clamped = spec.clamped(newValue)
        if clamped != value { value = clamped }
    }

    /// SwiftUI on macOS 14 has no scroll-wheel modifier, so watch scroll
    /// events while the pointer is over this knob and consume them.
    private func installScrollMonitor() {
        guard scrollMonitor == nil else { return }
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
            guard scrollAdjusts, isHovering, isEnabled, !isEditing else { return event }
            let delta = event.scrollingDeltaY
            guard delta != 0 else { return nil }
            // Trackpads report many small precise deltas; wheels report whole lines.
            let steps = event.hasPreciseScrollingDeltas ? Double(delta) / 10 : Double(delta)
            nudge(by: steps)
            return nil
        }
    }

    private func removeScrollMonitor() {
        if let scrollMonitor { NSEvent.removeMonitor(scrollMonitor) }
        scrollMonitor = nil
    }

    // MARK: Exact value entry

    @ViewBuilder
    private var valueField: some View {
        if isEditing {
            TextField("", text: $editText)
                .textFieldStyle(.plain)
                .multilineTextAlignment(.center)
                .font(Self.valueFont)
                .frame(width: 64, height: 20)
                .voltaFieldSurface(focused: isTextFieldFocused)
                .focused($isTextFieldFocused)
                .onSubmit(commitEdit)
                .onExitCommand(perform: cancelEdit)
                .onChange(of: isTextFieldFocused) { _, focused in
                    if !focused, isEditing { commitEdit() }
                }
                .onAppear { isTextFieldFocused = true }
        } else {
            Button(displayedValue, action: beginEdit)
                .buttonStyle(.voltaHover)
                .font(Self.valueFont)
                .foregroundStyle(.primary)
                .frame(width: 64, height: 20)
                .help("Click to type a value")
                .accessibilityLabel("\(label) value")
                .accessibilityHint("Edit to type an exact value")
        }
    }

    private var displayedValue: String {
        if !isEnabled, let disabledText { return disabledText }
        return spec.format(value)
    }

    private func beginEdit() {
        editText = spec.format(value)
        isEditing = true
    }

    private func commitEdit() {
        if let parsed = spec.parse(editText) { setValue(parsed) }
        isEditing = false
    }

    private func cancelEdit() {
        isEditing = false
    }
}
