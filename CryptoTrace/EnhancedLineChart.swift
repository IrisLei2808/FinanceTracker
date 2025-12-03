import SwiftUI

struct EnhancedLineChart: View {
    let points: [Double]
    let accent: Color

    private var normalized: [CGPoint] {
        guard points.count >= 2, let min = points.min(), let max = points.max(), max > min else {
            // Flat line if not enough variance
            return points.enumerated().map { (i, _) in
                CGPoint(x: CGFloat(i), y: 0.5)
            }
        }
        let range = max - min
        return points.enumerated().map { (i, v) in
            let x = CGFloat(i)
            // Normalize so that higher values are visually higher (y inverted in SwiftUI)
            let y = CGFloat((v - min) / range)
            return CGPoint(x: x, y: y)
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let pts = normalized
            let count = max(pts.count - 1, 1)
            let dx = count > 0 ? w / CGFloat(count) : 0

            // Build path
            let path = Path { p in
                guard !pts.isEmpty else { return }
                let start = CGPoint(x: 0, y: (1 - pts[0].y) * h)
                p.move(to: start)
                for i in 1..<pts.count {
                    let pt = CGPoint(x: CGFloat(i) * dx, y: (1 - pts[i].y) * h)
                    p.addLine(to: pt)
                }
            }

            // Fill under curve
            let fillPath = Path { p in
                guard !pts.isEmpty else { return }
                let start = CGPoint(x: 0, y: (1 - pts[0].y) * h)
                p.move(to: start)
                for i in 1..<pts.count {
                    let pt = CGPoint(x: CGFloat(i) * dx, y: (1 - pts[i].y) * h)
                    p.addLine(to: pt)
                }
                // Close to bottom
                p.addLine(to: CGPoint(x: CGFloat(pts.count - 1) * dx, y: h))
                p.addLine(to: CGPoint(x: 0, y: h))
                p.closeSubpath()
            }

            ZStack {
                fillPath
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(0.25), accent.opacity(0.05), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                path
                    .stroke(
                        accent,
                        style: StrokeStyle(
                            lineWidth: 2,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
            }
        }
        .drawingGroup()
        .accessibilityLabel("Price history chart")
    }
}

#Preview {
    VStack {
        EnhancedLineChart(points: (0..<60).map { i in
            let t = Double(i) / 59.0
            return 100 + 10 * sin(t * .pi * 2) + Double.random(in: -1...1)
        }, accent: .green)
        .frame(height: 200)
        .padding()
    }
}
