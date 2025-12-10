import SwiftUI

struct DonutChart: View {
    struct Segment: Identifiable {
        let id: Int
        let value: Double
        let label: String
        let color: Color
    }

    let segments: [Segment]

    // Optional hole size (0 = pie, 0.6 = typical donut)
    var innerRadiusRatio: CGFloat = 0.6
    // Optional spacing between segments in radians
    var gapRadians: CGFloat = .pi / 180 // 1 degree gaps

    private var total: Double {
        let sum = segments.map(\.value).reduce(0, +)
        return sum.isFinite && sum > 0 ? sum : 1 // avoid division by zero
    }

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let radius = size / 2
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let holeRadius = radius * max(0, min(1, innerRadiusRatio))

            ZStack {
                // Background ring to show empty state subtly
                Circle()
                    .stroke(Color.gray.opacity(0.12), lineWidth: radius - holeRadius)
                    .frame(width: radius * 2, height: radius * 2)
                    .position(center)

                // Draw segments
                ForEach(angles(), id: \.id) { arc in
                    DonutSegmentShape(
                        startAngle: arc.start,
                        endAngle: arc.end,
                        innerRadius: holeRadius
                    )
                    .fill(segments.first(where: { $0.id == arc.id })?.color ?? .accentColor)
                    .overlay(
                        DonutSegmentShape(
                            startAngle: arc.start,
                            endAngle: arc.end,
                            innerRadius: holeRadius
                        )
                        .stroke(Color.white.opacity(0.6), lineWidth: 0.5) // subtle divider
                    )
                    .frame(width: radius * 2, height: radius * 2)
                    .position(center)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Allocation")
        .accessibilityValue(accessibilitySummary())
    }

    // Convert values to start/end angles with small gaps
    private func angles() -> [(id: Int, start: Angle, end: Angle)] {
        var result: [(Int, Angle, Angle)] = []
        guard !segments.isEmpty else { return result }

        let sum = total
        let gap = gapRadians
        let totalGap = gap * CGFloat(segments.count)
        let full = 2 * CGFloat.pi - totalGap

        var current = -CGFloat.pi / 2 // start at 12 o’clock
        for s in segments {
            let pct = CGFloat(max(0, s.value) / sum)
            let sweep = full * pct
            let start = current
            let end = current + sweep
            result.append((s.id, Angle(radians: Double(start)), Angle(radians: Double(end))))
            current = end + gap
        }
        return result
    }

    private func accessibilitySummary() -> String {
        let sum = total
        let parts = segments.map { s -> String in
            let pct = s.value / sum * 100
            return "\(s.label) \(String(format: "%.1f", pct))%"
        }
        return parts.joined(separator: ", ")
    }
}

// Shape for a donut arc between start and end angles with inner radius
private struct DonutSegmentShape: Shape {
    let startAngle: Angle
    let endAngle: Angle
    let innerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2

        var p = Path()

        // Clamp if start == end (no area)
        guard startAngle != endAngle else { return p }

        // Build outer arc
        p.addArc(center: center,
                 radius: outerRadius,
                 startAngle: startAngle,
                 endAngle: endAngle,
                 clockwise: false)

        // Add line to inner arc end
        let endPointInner = CGPoint(
            x: center.x + innerRadius * CGFloat(cos(endAngle.radians)),
            y: center.y + innerRadius * CGFloat(sin(endAngle.radians))
        )
        p.addLine(to: endPointInner)

        // Inner arc (reverse)
        p.addArc(center: center,
                 radius: innerRadius,
                 startAngle: endAngle,
                 endAngle: startAngle,
                 clockwise: true)

        p.closeSubpath()
        return p
    }
}

#Preview {
    let sample: [DonutChart.Segment] = [
        .init(id: 1, value: 40, label: "BTC", color: .orange),
        .init(id: 2, value: 25, label: "ETH", color: .blue),
        .init(id: 3, value: 15, label: "SOL", color: .green),
        .init(id: 4, value: 20, label: "Other", color: .purple)
    ]
    return VStack {
        DonutChart(segments: sample)
            .frame(height: 220)
            .padding()
    }
}
