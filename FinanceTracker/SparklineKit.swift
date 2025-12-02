import SwiftUI

// Shared sparkline generator and view for reuse across screens.
enum SparklineBuilder {
    static func series(current: Double, percentChange: Double?, count: Int = 24) -> [Double] {
        guard current.isFinite, current > 0, let pct = percentChange else { return [] }
        let growth = 1.0 + pct / 100.0
        guard growth > 0 else { return [] }
        let start = current / growth
        return synthSeries(start: start, end: current, count: count)
    }

    // Smooth synthetic series with small wiggles; deterministic enough for UI.
    static func synthSeries(start: Double, end: Double, count: Int) -> [Double] {
        guard count >= 2 else { return [start, end] }
        let ratio = max(1e-9, end / start)
        var out: [Double] = []
        out.reserveCapacity(count)

        // Simple smooth path with small wiggle
        let phase1 = Double.random(in: 0...(2 * .pi))
        let phase2 = Double.random(in: 0...(2 * .pi))

        func taper(_ t: Double) -> Double {
            let s = t * (1 - t)
            return s * 4
        }

        for i in 0..<count {
            let t = Double(i) / Double(count - 1)
            let base = start * pow(ratio, t)
            let w1 = sin(2 * .pi * (2.0 * t) + phase1)
            let w2 = sin(2 * .pi * (5.0 * t) + phase2)
            let noise = (Double.random(in: 0...1) - 0.5) * 0.3
            let wiggle = (0.65 * w1 + 0.35 * w2 + 0.2 * noise)
            let amp = 0.006 * taper(t)
            let val = base * (1.0 + amp * wiggle)
            out.append(val)
        }
        out[0] = start
        out[count - 1] = end
        return out
    }
}

struct SparklineView: View {
    let points: [Double]
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            if points.count >= 2, let min = points.min(), let max = points.max(), max > min {
                let norm = points.enumerated().map { (i, v) -> CGPoint in
                    let x = CGFloat(i) / CGFloat(points.count - 1) * w
                    let y = (1 - CGFloat((v - min) / (max - min))) * h
                    return CGPoint(x: x, y: y)
                }
                Path { path in
                    path.addLines(norm)
                }
                .stroke(tint, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            } else {
                Path { path in
                    path.move(to: CGPoint(x: 0, y: h * 0.6))
                    path.addLine(to: CGPoint(x: w, y: h * 0.6))
                }
                .stroke(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
        }
    }
}

