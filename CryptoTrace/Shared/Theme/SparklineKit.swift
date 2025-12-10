import SwiftUI

// Shared sparkline generator and view for reuse across screens.
enum SparklineBuilder {
    static func series(current: Double, percentChange: Double?, count: Int = 24) -> [Double] {
        guard current.isFinite, current > 0, let pct = percentChange else { return [] }
        let growth = 1.0 + pct / 100.0
        guard growth > 0 else { return [] }
        let start = current / growth
        return synthSeries(start: start, end: current, count: count, volatility: 0.35, seed: UInt64(bitPattern: Int64(start.hashValue ^ current.hashValue)))
    }

    // Smooth synthetic series with small wiggles; deterministic enough for UI.
    static func synthSeries(start: Double, end: Double, count: Int, volatility: Double = 0.35, seed: UInt64? = nil) -> [Double] {
        guard count >= 2 else { return [start, end] }
        let ratio = max(1e-9, end / max(start, 1e-9))
        var out: [Double] = []
        out.reserveCapacity(count)

        // Deterministic random generator (LCG) if seed provided
        struct LCG {
            var state: UInt64
            mutating func next() -> UInt64 {
                state = 6364136223846793005 &* state &+ 1
                return state
            }
            mutating func nextDouble() -> Double {
                let v = next() >> 11 // 53 bits
                return Double(v) / Double(1 << 53)
            }
        }
        var rng = LCG(state: seed ?? UInt64.random(in: 0..<UInt64.max))

        // Simple smooth path with small wiggle
        let phase1 = (seed != nil ? rng.nextDouble() : Double.random(in: 0...(2 * .pi))) * (2 * .pi)
        let phase2 = (seed != nil ? rng.nextDouble() : Double.random(in: 0...(2 * .pi))) * (2 * .pi)

        func taper(_ t: Double) -> Double {
            let s = t * (1 - t)
            return s * 4
        }

        // Clamp volatility 0...1
        let vol = max(0, min(1, volatility))
        let wiggleBaseAmp = 0.006 * (0.3 + 0.7 * vol)

        for i in 0..<count {
            let t = Double(i) / Double(count - 1)
            let base = max(1e-9, start) * pow(ratio, t)
            let w1 = sin(2 * .pi * (2.0 * t) + phase1)
            let w2 = sin(2 * .pi * (5.0 * t) + phase2)
            let noise = ((seed != nil ? rng.nextDouble() : Double.random(in: 0...1)) - 0.5) * 0.3
            let wiggle = (0.65 * w1 + 0.35 * w2 + 0.2 * noise)
            let amp = wiggleBaseAmp * taper(t)
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

    // New configuration (defaults keep current behavior simple)
    var areaFill: Bool = true
    var endMarker: Bool = true
    var smooth: Bool = true
    var animate: Bool = true

    @State private var animProgress: CGFloat = 0
    @State private var cachedPoints: [Double] = []

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height

            if points.count >= 2, let minV = points.min(), let maxV = points.max(), maxV > minV {
                let trendUp = (points.last ?? 0) >= (points.first ?? 0)

                // Normalize to [0,1] coordinates, then scale to view
                let normPts: [CGPoint] = normalized(points: points, min: minV, max: maxV, width: w, height: h)

                // Smoothed or polyline path
                let path: Path = {
                    if smooth {
                        return catmullRomSpline(points: normPts)
                    } else {
                        var p = Path()
                        p.addLines(normPts)
                        return p
                    }
                }()

                // Gradient stroke based on trend, modulated by provided tint
                let strokeGradient = LinearGradient(
                    colors: gradientColors(for: trendUp, base: tint),
                    startPoint: .leading, endPoint: .trailing
                )

                // Area fill under the curve
                if areaFill {
                    let fillPath = path.closedToBottom(height: h)
                    fillPath
                        .fill(
                            LinearGradient(
                                colors: [
                                    (trendUp ? Color.green : Color.red).opacity(0.18),
                                    (trendUp ? Color.green : Color.red).opacity(0.05),
                                    Color.clear
                                ],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .opacity(0.8)
                        .animation(.easeInOut(duration: 0.25), value: points)
                }

                // Stroke with animated trim
                path
                    .trim(from: 0, to: animate && !UIAccessibility.isReduceMotionEnabled ? animProgress : 1)
                    .stroke(strokeGradient, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .onAppear {
                        cachedPoints = points
                        if animate && !UIAccessibility.isReduceMotionEnabled {
                            animProgress = 0
                            withAnimation(.easeOut(duration: 0.8)) {
                                animProgress = 1
                            }
                        } else {
                            animProgress = 1
                        }
                    }
                    .onChange(of: points) { _, newValue in
                        // Morph animation: reset trim and animate again
                        if animate && !UIAccessibility.isReduceMotionEnabled {
                            animProgress = 0
                            withAnimation(.easeOut(duration: 0.7)) {
                                animProgress = 1
                            }
                        } else {
                            animProgress = 1
                        }
                        cachedPoints = newValue
                    }

                // End marker
                if endMarker, let last = normPts.last {
                    Circle()
                        .fill((trendUp ? Color.green : Color.red).opacity(0.95))
                        .frame(width: 5, height: 5)
                        .position(last)
                        .transition(.scale.combined(with: .opacity))
                        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: points)
                }
            } else {
                // Fallback baseline
                Path { path in
                    path.move(to: CGPoint(x: 0, y: h * 0.6))
                    path.addLine(to: CGPoint(x: w, y: h * 0.6))
                }
                .stroke(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
        }
    }

    // MARK: - Helpers

    private func normalized(points: [Double], min: Double, max: Double, width: CGFloat, height: CGFloat) -> [CGPoint] {
        let denom = max - min
        guard denom > 0, points.count >= 2 else { return [] }
        let n = points.count
        return points.enumerated().map { (i, v) in
            let x = CGFloat(i) / CGFloat(n - 1) * width
            let y = (1 - CGFloat((v - min) / denom)) * height
            return CGPoint(x: x, y: y)
        }
    }

    private func gradientColors(for up: Bool, base: Color) -> [Color] {
        if up {
            // Blend base tint with green/mint
            return [
                Color.green.opacity(0.95),
                base.opacity(0.9),
                Color.mint.opacity(0.9)
            ]
        } else {
            return [
                Color.red.opacity(0.95),
                base.opacity(0.9),
                Color.orange.opacity(0.9)
            ]
        }
    }
}

// MARK: - Path smoothing and utilities

private func catmullRomSpline(points: [CGPoint], alpha: CGFloat = 0.5) -> Path {
    var path = Path()
    guard points.count >= 2 else { return path }

    let pts = points
    path.move(to: pts[0])

    // Duplicate endpoints for boundary handling
    var p0 = pts[0]
    var p1 = pts[0]
    var p2 = pts[1]
    var p3 = pts.count > 2 ? pts[2] : pts[1]

    // First segment
    addCatmullSegment(path: &path, p0: p0, p1: p1, p2: p2, p3: p3, alpha: alpha)

    for i in 1..<(pts.count - 1) {
        p0 = pts[i - 1]
        p1 = pts[i]
        p2 = pts[i + 1]
        p3 = i + 2 < pts.count ? pts[i + 2] : pts[i + 1]
        addCatmullSegment(path: &path, p0: p0, p1: p1, p2: p2, p3: p3, alpha: alpha)
    }

    return path
}

private func addCatmullSegment(path: inout Path, p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint, alpha: CGFloat) {
    // Catmull-Rom to cubic Bezier conversion with centripetal parameterization
    func t(_ pi: CGPoint, _ pj: CGPoint, _ tPrev: CGFloat) -> CGFloat {
        let d = hypot(pj.x - pi.x, pj.y - pi.y)
        return tPrev + pow(d, alpha)
    }

    let t0: CGFloat = 0
    let t1 = t(p0, p1, t0)
    let t2 = t(p1, p2, t1)
    let t3 = t(p2, p3, t2)

    func A(_ t: CGFloat, _ t0: CGFloat, _ t1: CGFloat, _ p0: CGPoint, _ p1: CGPoint) -> CGPoint {
        let w = (t - t0) / (t1 - t0)
        return CGPoint(x: (1 - w) * p0.x + w * p1.x, y: (1 - w) * p0.y + w * p1.y)
    }

    let m1 = CGPoint(
        x: (p2.x - p0.x) / (t2 - t0),
        y: (p2.y - p0.y) / (t2 - t0)
    )
    let m2 = CGPoint(
        x: (p3.x - p1.x) / (t3 - t1),
        y: (p3.y - p1.y) / (t3 - t1)
    )

    // Convert to cubic control points
    let dt1 = t2 - t1
    let c1 = CGPoint(x: p1.x + m1.x * dt1 / 3.0, y: p1.y + m1.y * dt1 / 3.0)
    let c2 = CGPoint(x: p2.x - m2.x * dt1 / 3.0, y: p2.y - m2.y * dt1 / 3.0)

    path.addCurve(to: p2, control1: c1, control2: c2)
}

private extension Path {
    func closedToBottom(height: CGFloat) -> Path {
        var p = self
        var rect = Path()
        // Close path to bottom to create fill area
        if let lastPoint = currentEndPoint() {
            p.addLine(to: CGPoint(x: lastPoint.x, y: height))
            p.addLine(to: CGPoint(x: 0, y: height))
            p.closeSubpath()
            return p
        } else {
            // Fallback: just return a rectangle of zero height
            rect.addRect(CGRect(x: 0, y: height, width: 0, height: 0))
            return rect
        }
    }

    // Attempts to get the current end point by walking the path
    func currentEndPoint() -> CGPoint? {
        var last: CGPoint?
        self.forEach { element in
            switch element {
            case .move(to: let p): last = p
            case .line(to: let p): last = p
            case .quadCurve(to: let p, control: _): last = p
            case .curve(to: let p, control1: _, control2: _): last = p
            case .closeSubpath: break
            }
        }
        return last
    }
}
