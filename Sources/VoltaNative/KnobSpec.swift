import Foundation

/// Range, default, step and display rules for one knob. Pure value type, so it is unit tested.
///
/// Define a plugin's specs next to its parameter definitions (for example `extension KnobSpec { static let mix = … }`)
/// so the UI reads them from one place.
public struct KnobSpec: Sendable, Equatable {
    public let range: ClosedRange<Double>
    public let defaultValue: Double
    /// Arrow-key and scroll step, in parameter units. Logarithmic knobs step
    /// by 1% of their travel instead.
    public let step: Double
    /// Multiplier from parameter units to display units (0...1 shown as 0...100%).
    public let displayScale: Double
    public let unitSuffix: String
    public let showsSign: Bool
    /// Frequency-like ranges spread evenly by ratio, so the low end isn't cramped.
    public var isLogarithmic: Bool

    public init(range: ClosedRange<Double>, defaultValue: Double, step: Double, displayScale: Double = 1,
                unitSuffix: String = "", showsSign: Bool = false, isLogarithmic: Bool = false) {
        self.range = range
        self.defaultValue = defaultValue
        self.step = step
        self.displayScale = displayScale
        self.unitSuffix = unitSuffix
        self.showsSign = showsSign
        self.isLogarithmic = isLogarithmic
    }

    private static let logarithmicStep = 0.01

    /// Bipolar knobs fill their arc from the center.
    public var isBipolar: Bool { range.lowerBound < 0 && range.upperBound > 0 }

    public func clamped(_ value: Double) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }

    /// Position along the knob's travel, 0...1.
    public func normalized(_ value: Double) -> Double {
        let low = range.lowerBound, high = range.upperBound
        guard high > low else { return 0 }
        if isLogarithmic { return log(clamped(value) / low) / log(high / low) }
        return (clamped(value) - low) / (high - low)
    }

    public func value(atNormalized position: Double) -> Double {
        let position = min(max(position, 0), 1)
        let low = range.lowerBound, high = range.upperBound
        if isLogarithmic { return low * pow(high / low, position) }
        return low + position * (high - low)
    }

    /// `value` moved by `steps` arrow-key steps.
    public func stepped(_ value: Double, by steps: Double) -> Double {
        if isLogarithmic { return self.value(atNormalized: normalized(value) + steps * Self.logarithmicStep) }
        return clamped(value + steps * step)
    }

    public func format(_ value: Double) -> String {
        let shown = value * displayScale
        let isWhole = abs(shown - shown.rounded()) < 0.05
        let sign = showsSign && shown.rounded() != 0 ? "+" : ""
        let number = String(format: "%\(sign).\(isWhole ? 0 : 1)f", isWhole ? shown.rounded() : shown)
        return number + unitSuffix
    }

    /// Accepts typed text with or without units ("50%", "50", "+3 st").
    /// Returns nil when there's no number, so the value stays unchanged.
    public func parse(_ text: String) -> Double? {
        let numeric = text.filter { "0123456789.-+".contains($0) }
        guard let shown = Double(numeric) else { return nil }
        return clamped(shown / displayScale)
    }
}
