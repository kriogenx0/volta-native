import SwiftUI

/// Initials on a tinted rounded square. The tint is picked from the name, so a name always gets the same color.
public struct VoltaAvatar: View {
    let name: String
    var size: CGFloat

    public init(name: String, size: CGFloat = VoltaTokens.sizeAvatar) {
        self.name = name
        self.size = size
    }

    public var body: some View {
        let initials = name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
        let palette: [Color] = [.teal, .indigo, .orange, .pink, .blue]
        let color = palette[name.utf8.reduce(0) { ($0 + Int($1)) % palette.count }]
        Text(initials.isEmpty ? "?" : initials)
            .font(.system(size: size * 0.32, weight: .semibold, design: .rounded))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: size * 0.32))
            .textSelection(.disabled)
            .accessibilityHidden(true)
    }
}

/// A small capsule label with an optional SF Symbol. Unapplied chips show only an outline.
public struct VoltaChip: View {
    let title: String
    let symbol: String?
    let color: Color
    var isApplied: Bool

    public init(_ title: String, symbol: String? = nil, color: Color = .voltaAccent, isApplied: Bool = true) {
        self.title = title
        self.symbol = symbol
        self.color = color
        self.isApplied = isApplied
    }

    public var body: some View {
        Group {
            if let symbol { Label(title, systemImage: symbol) } else { Text(title) }
        }
        .font(.system(size: 10, weight: .medium))
        .padding(.horizontal, 7).padding(.vertical, 3)
        .foregroundStyle(isApplied ? color : .secondary)
        .background(isApplied ? color.opacity(0.10) : .clear, in: Capsule())
        .overlay(Capsule().strokeBorder(isApplied ? Color.clear : Color.secondary.opacity(VoltaDesign.boundaryOpacity), lineWidth: 1))
        .textSelection(.disabled)
    }
}

/// A centered icon, title and subtitle for views with nothing to show yet.
public struct VoltaEmptyState: View {
    let icon: String
    let title: String
    let subtitle: String
    @Environment(\.voltaAccent) private var accent

    public init(icon: String, title: String, subtitle: String) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
    }

    public var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 38, weight: .light)).foregroundStyle(accent.opacity(0.7))
            Text(title).font(.title2.weight(.semibold))
            Text(subtitle).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 300)
        }.padding(24).frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Wraps children onto new rows so every item stays visible in narrow views.
public struct VoltaFlowLayout: Layout {
    var spacing: CGFloat
    var alignment: HorizontalAlignment

    public init(spacing: CGFloat = 7, alignment: HorizontalAlignment = .leading) {
        self.spacing = spacing
        self.alignment = alignment
    }

    /// Positions for items of the given sizes in rows no wider than `width`. Exposed for tests.
    public static func arrange(sizes: [CGSize], width: CGFloat, spacing: CGFloat) -> (points: [CGPoint], size: CGSize) {
        var points: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var usedWidth: CGFloat = 0
        for size in sizes {
            if x > 0 && x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            points.append(CGPoint(x: x, y: y))
            usedWidth = max(usedWidth, x + size.width)
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        return (points, CGSize(width: usedWidth, height: y + rowHeight))
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        Self.arrange(sizes: subviews.map { $0.sizeThatFits(.unspecified) },
                     width: proposal.width ?? .greatestFiniteMagnitude, spacing: spacing).size
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let points = Self.arrange(sizes: sizes, width: bounds.width, spacing: spacing).points
        var rowWidths: [CGFloat: CGFloat] = [:]
        for (index, point) in points.enumerated() {
            rowWidths[point.y] = max(rowWidths[point.y] ?? 0, point.x + sizes[index].width)
        }
        for (index, subview) in subviews.enumerated() {
            let point = points[index]
            let offset = alignment == .trailing ? max(0, bounds.width - (rowWidths[point.y] ?? 0)) : 0
            subview.place(at: CGPoint(x: bounds.minX + point.x + offset, y: bounds.minY + point.y), anchor: .topLeading, proposal: .unspecified)
        }
    }
}
