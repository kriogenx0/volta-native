import SwiftUI

/// The meaning of a status color, shared by badges, status dots and messages. `info` uses the accent.
public enum VoltaTone: Int, CaseIterable, Sendable {
    case neutral, info, success, warning, danger

    /// The tone's color. Pass the environment accent so `info` follows app overrides.
    public func color(accent: Color) -> Color {
        switch self {
        case .neutral: return .secondary
        case .info: return accent
        case .success: return .green
        case .warning: return .orange
        case .danger: return .red
        }
    }

    var symbol: String {
        switch self {
        case .neutral, .info: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .danger: return "xmark.octagon.fill"
        }
    }
}

// MARK: Badge

/// A short status word on a tinted capsule, such as "Paid" or "Overdue". Not clickable.
public struct VoltaBadge: View {
    let title: String
    let tone: VoltaTone
    @Environment(\.voltaAccent) private var accent

    public init(_ title: String, tone: VoltaTone = .neutral) {
        self.title = title
        self.tone = tone
    }

    public var body: some View {
        let color = tone.color(accent: accent)
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 8).padding(.vertical, 2)
            .foregroundStyle(color)
            .background(color.opacity(tone == .neutral ? 0.12 : 0.14), in: Capsule())
            .textSelection(.disabled)
    }
}

// MARK: Status dot

/// A small filled circle that marks a row's state, with an optional label after it.
public struct VoltaStatusDot: View {
    let tone: VoltaTone
    let label: String?
    var size: CGFloat
    @Environment(\.voltaAccent) private var accent

    public init(_ tone: VoltaTone, label: String? = nil, size: CGFloat = VoltaTokens.sizeStatusDot) {
        self.tone = tone
        self.label = label
        self.size = size
    }

    public var body: some View {
        HStack(spacing: 6) {
            Circle().fill(tone.color(accent: accent)).frame(width: size, height: size)
            if let label { Text(label).font(.callout).foregroundStyle(.secondary) }
        }
        .textSelection(.disabled)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label ?? String(describing: tone))
    }
}

// MARK: Message

/// An inline notice with a tone icon, for results such as "Saved" or a validation error. Not clickable.
public struct VoltaMessage: View {
    let text: String
    let tone: VoltaTone
    @Environment(\.voltaAccent) private var accent

    public init(_ text: String, tone: VoltaTone = .info) {
        self.text = text
        self.tone = tone
    }

    public var body: some View {
        let color = tone.color(accent: accent)
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: tone.symbol).foregroundStyle(color).accessibilityHidden(true)
            Text(text).fixedSize(horizontal: false, vertical: true)
        }
        .font(.callout)
        .padding(.horizontal, 12).padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: VoltaDesign.cornerRadius))
        .overlay(RoundedRectangle(cornerRadius: VoltaDesign.cornerRadius).strokeBorder(color.opacity(0.25), lineWidth: 1))
    }
}

// MARK: Progress bar

/// A thin accent bar. Pass `nil` while the amount of work is unknown and a segment sweeps back and forth.
public struct VoltaProgressBar: View {
    @Environment(\.voltaPalette) private var palette
    let value: Double?
    @Environment(\.voltaAccent) private var accent
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// `value` runs from 0 to 1 and is clamped.
    public init(value: Double?) { self.value = value }

    /// Length of the sweeping segment, as a fraction of the track.
    public static let sweepLength = 0.3
    /// Seconds for one sweep there and back.
    public static let sweepPeriod = 2.4

    /// Leading edge of the sweeping segment at `time`, from 0 to `1 - sweepLength`. Exposed for tests.
    public static func sweepOffset(at time: TimeInterval) -> Double {
        let phase = time.truncatingRemainder(dividingBy: sweepPeriod) / sweepPeriod
        let eased = (1 - cos(phase * 2 * .pi)) / 2
        return eased * (1 - sweepLength)
    }

    public var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(palette.secondary.opacity(0.16))
                if let value {
                    Capsule().fill(accent).frame(width: width * min(max(value, 0), 1))
                        .animation(VoltaDesign.animation, value: value)
                } else if reduceMotion {
                    Capsule().fill(accent.opacity(0.45))
                } else {
                    TimelineView(.animation) { context in
                        let offset = Self.sweepOffset(at: context.date.timeIntervalSinceReferenceDate)
                        Capsule().fill(accent).frame(width: width * Self.sweepLength).offset(x: width * offset)
                    }
                }
            }
        }
        .frame(height: VoltaTokens.sizeProgressHeight)
        .clipShape(Capsule())
        .accessibilityElement()
        .accessibilityLabel("Progress")
        .accessibilityValue(value.map { "\(Int((min(max($0, 0), 1) * 100).rounded())) percent" } ?? "In progress")
    }
}

// MARK: Spinner

/// Twelve fading arms, for short waits where a progress bar would be too much.
public struct VoltaSpinner: View {
    @Environment(\.voltaPalette) private var palette
    var size: CGFloat

    public init(size: CGFloat = VoltaTokens.sizeSpinner) { self.size = size }

    static let arms = 12

    /// Opacity of `arm` when the brightest arm is `step`. Arms fade over the following positions. Exposed for tests.
    public static func armOpacity(arm: Int, step: Int) -> Double {
        let behind = ((step - arm) % arms + arms) % arms
        return max(0.15, 1 - Double(behind) / Double(arms) * 1.1)
    }

    public var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0 / Double(Self.arms))) { context in
            let step = Int(context.date.timeIntervalSinceReferenceDate * Double(Self.arms)) % Self.arms
            ZStack {
                ForEach(0..<Self.arms, id: \.self) { arm in
                    Capsule()
                        .fill(palette.secondary)
                        .frame(width: max(1.5, size * 0.09), height: size * 0.27)
                        .offset(y: -size * 0.31)
                        .rotationEffect(.degrees(Double(arm) * 360 / Double(Self.arms)))
                        .opacity(Self.armOpacity(arm: arm, step: step))
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityLabel("Loading")
    }
}
