import Foundation
import SwiftUI
import Combine

struct Holding: Identifiable, Codable, Hashable {
    let id: UUID
    var coinId: Int
    var amount: Double
    var costPerUnit: Double
    var note: String?
    var date: Date?

    init(id: UUID = UUID(), coinId: Int, amount: Double, costPerUnit: Double, note: String? = nil, date: Date? = nil) {
        self.id = id
        self.coinId = coinId
        self.amount = amount
        self.costPerUnit = costPerUnit
        self.note = note
        self.date = date
    }

    var costBasisTotal: Double { amount * costPerUnit }
}

@MainActor
final class PortfolioStore: ObservableObject {
    @Published private(set) var holdings: [Holding] = []

    private let defaultsKey = "portfolio.holdings"

    init() {
        load()
    }

    func add(_ holding: Holding) {
        holdings.append(holding)
        persist()
    }

    func update(_ holding: Holding) {
        guard let idx = holdings.firstIndex(where: { $0.id == holding.id }) else { return }
        holdings[idx] = holding
        persist()
    }

    func remove(_ id: UUID) {
        holdings.removeAll { $0.id == id }
        persist()
    }

    func removeAll() {
        holdings.removeAll()
        persist()
    }

    // MARK: - Aggregation

    func marketValue(for holding: Holding, with prices: [Int: Double]) -> Double {
        guard let price = prices[holding.coinId] else { return 0 }
        return holding.amount * price
    }

    func totalMarketValue(with prices: [Int: Double]) -> Double {
        holdings.reduce(0) { $0 + marketValue(for: $1, with: prices) }
    }

    var totalCostBasis: Double {
        holdings.reduce(0) { $0 + $1.costBasisTotal }
    }

    func unrealizedPL(with prices: [Int: Double]) -> Double {
        totalMarketValue(with: prices) - totalCostBasis
    }

    func dayChange(with coins: [Crypto], prices: [Int: Double]) -> Double {
        // Sum per holding: amount * price * (pct24h/100)
        var sum: Double = 0
        for h in holdings {
            guard let c = coins.first(where: { $0.id == h.coinId }),
                  let price = prices[h.coinId],
                  let pct = c.usd?.percent_change_24h else { continue }
            let val = h.amount * price
            sum += val * (pct / 100.0)
        }
        return sum
    }

    func priceMap(from coins: [Crypto]) -> [Int: Double] {
        var out: [Int: Double] = [:]
        for c in coins {
            if let p = c.usd?.price { out[c.id] = p }
        }
        return out
    }

    // Allocation data: [(coinId, value)]
    func allocations(with prices: [Int: Double]) -> [(Int, Double)] {
        let pairs = holdings
            .map { ($0.coinId, marketValue(for: $0, with: prices)) }
            .filter { $0.1 > 0 }
        // Aggregate by coinId
        var agg: [Int: Double] = [:]
        for (id, val) in pairs {
            agg[id, default: 0] += val
        }
        return agg.map { ($0.key, $0.value) }
            .sorted { $0.1 > $1.1 }
    }

    // MARK: - Persistence

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else {
            holdings = []
            return
        }
        do {
            let decoded = try JSONDecoder().decode([Holding].self, from: data)
            holdings = decoded
        } catch {
            print("Failed to decode holdings:", error)
            holdings = []
        }
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(holdings)
            UserDefaults.standard.set(data, forKey: defaultsKey)
        } catch {
            print("Failed to encode holdings:", error)
        }
    }
}

