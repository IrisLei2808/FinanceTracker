import Foundation
import Combine

@MainActor
final class PriceHistoryViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var points: [Double]?
    @Published var errorMessage: String?

    func loadHistory(for coinID: Int, range: PriceRange, coinProvider: () -> Crypto? = { nil }) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        guard let coin = coinProvider() ?? findCoin(by: coinID) else {
            self.points = []
            self.errorMessage = "Missing coin snapshot"
            return
        }

        if let series = generateSyntheticSeries(for: coin, range: range) {
            self.points = series
        } else {
            self.points = []
            self.errorMessage = "Not enough data to build chart"
        }
    }

    // Try to find a coin snapshot if provider not supplied (no-op here; hook into your storage if desired)
    private func findCoin(by id: Int) -> Crypto? {
        // In this project, CoinDetailView passes the coin via coinProvider, so we can just return nil.
        return nil
    }

    // MARK: - Synthetic series

    private func generateSyntheticSeries(for coin: Crypto, range: PriceRange) -> [Double]? {
        guard let current = coin.usd?.price, current.isFinite, current > 0 else { return nil }

        // Determine target percent change and number of points for the selected range
        let (pctChange, pointsCount, seed, granularity) = params(for: range, coin: coin)
        guard let pctChange else { return nil }

        // Reconstruct start price using percent change: current = start * (1 + pct/100)
        let growth = 1.0 + pctChange / 100.0
        guard growth > 0 else { return nil }
        let start = current / growth

        // Generate smooth path with local wiggles
        let series = synthSeries(start: start, end: current, count: pointsCount, seed: seed, wiggleScale: wiggleScale(for: range), granularity: granularity)

        return series
    }

    // Define parameters per range
    private func params(for range: PriceRange, coin: Crypto) -> (pctChange: Double?, points: Int, seed: UInt64, granularity: TimeInterval) {
        switch range {
        case .h1:
            // 60 minutes -> minute-level points
            return (coin.usd?.percent_change_1h, 60, seedFor(coin, "h1"), 60)
        case .d1:
            // 24h -> 15-minute points (96)
            return (coin.usd?.percent_change_24h, 96, seedFor(coin, "d1"), 15 * 60)
        case .w1:
            // 7d -> hourly points (168)
            return (coin.usd?.percent_change_7d, 168, seedFor(coin, "w1"), 60 * 60)
        case .m1:
            // Approximate from 7d change scaled to ~30d
            if let w = coin.usd?.percent_change_7d {
                // Assume compounding weekly -> approximate monthly change
                let monthly = (pow(1 + w/100.0, 30.0/7.0) - 1) * 100.0
                return (monthly, 120, seedFor(coin, "m1"), 6 * 60 * 60) // 6-hour points
            } else if let d = coin.usd?.percent_change_24h {
                let monthly = (pow(1 + d/100.0, 30.0) - 1) * 100.0
                return (monthly, 120, seedFor(coin, "m1d"), 6 * 60 * 60)
            } else {
                return (nil, 0, 0, 0)
            }
        case .y1:
            // Approximate from 7d change scaled to ~365d
            if let w = coin.usd?.percent_change_7d {
                let yearly = (pow(1 + w/100.0, 365.0/7.0) - 1) * 100.0
                return (yearly, 180, seedFor(coin, "y1"), 24 * 60 * 60) // daily points
            } else if let d = coin.usd?.percent_change_24h {
                let yearly = (pow(1 + d/100.0, 365.0) - 1) * 100.0
                return (yearly, 180, seedFor(coin, "y1d"), 24 * 60 * 60)
            } else {
                return (nil, 0, 0, 0)
            }
        }
    }

    private func wiggleScale(for range: PriceRange) -> Double {
        switch range {
        case .h1: return 0.0025   // 0.25%
        case .d1: return 0.005    // 0.5%
        case .w1: return 0.01     // 1%
        case .m1: return 0.015    // 1.5%
        case .y1: return 0.02     // 2%
        }
    }

    private func seedFor(_ coin: Crypto, _ tag: String) -> UInt64 {
        // Stable seed per coin and range to make the wiggle deterministic between reloads
        var hasher = Hasher()
        hasher.combine(coin.id)
        hasher.combine(tag)
        return UInt64(bitPattern: Int64(hasher.finalize()))
    }

    // Generate a smooth series from start -> end with small wiggles
    private func synthSeries(start: Double, end: Double, count: Int, seed: UInt64, wiggleScale: Double, granularity: TimeInterval) -> [Double] {
        guard count >= 2 else { return [start, end] }

        // Exponential baseline ensures compounding matches total change
        // baseline(t) = start * pow(end/start, t), where t in [0,1]
        let ratio = max(1e-9, end / start)

        // Simple deterministic pseudo-random generator (Xorshift64*)
        var rngState = seed != 0 ? seed : 0x9E3779B97F4A7C15
        func randUnit() -> Double {
            // xorshift64*
            rngState ^= rngState >> 12
            rngState ^= rngState << 25
            rngState ^= rngState >> 27
            let x = rngState &* 2685821657736338717
            // Map to [0,1)
            return Double(x & 0xFFFFFFFFFFFF) / Double(0x1000000000000)
        }

        // Smooth periodic wiggle combining multiple sine waves with small random phase
        let phase1 = randUnit() * 2 * .pi
        let phase2 = randUnit() * 2 * .pi
        let phase3 = randUnit() * 2 * .pi

        // Amplitude taper: smaller near ends to ensure exact endpoints
        func taper(_ t: Double) -> Double {
            // Smoothstep-like envelope: t*(1-t) scaled
            let s = t * (1 - t)
            return s * 4 // peak 1.0 at t=0.5
        }

        var out: [Double] = []
        out.reserveCapacity(count)

        for i in 0..<count {
            let t = Double(i) / Double(count - 1) // 0..1
            let base = start * pow(ratio, t)

            // Compose wiggles
            let w1 = sin(2 * .pi * (2.0 * t) + phase1) // 2 cycles
            let w2 = sin(2 * .pi * (5.0 * t) + phase2) // 5 cycles
            let w3 = sin(2 * .pi * (11.0 * t) + phase3) // 11 cycles

            // Small random jitter per point for natural variation
            let noise = (randUnit() - 0.5) * 0.5 // [-0.25, 0.25]

            // Aggregate wiggle scaled by taper and price level
            let wiggle = (0.55 * w1 + 0.3 * w2 + 0.15 * w3 + 0.2 * noise)
            let amplitude = wiggleScale * taper(t)
            let value = base * (1.0 + amplitude * wiggle)

            out.append(value)
        }

        // Ensure exact endpoints
        out[0] = start
        out[count - 1] = end

        return out
    }
}
