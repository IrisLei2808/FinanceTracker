//
//  CoinMarketCapModels.swift
//  FinanceTracker
//
//  Created by Owner on 11/30/25.
//

import Foundation

struct ListingsResponse: Codable {
    let data: [Crypto]
}

struct Crypto: Codable, Identifiable {
    let id: Int
    let name: String
    let symbol: String
    let slug: String?
    let cmc_rank: Int?
    let last_updated: String?
    let quote: [String: FiatQuote]

    var usd: FiatQuote? { quote["USD"] }
}

struct FiatQuote: Codable {
    let price: Double
    let volume_24h: Double?
    let volume_change_24h: Double?
    let percent_change_1h: Double?
    let percent_change_24h: Double?
    let percent_change_7d: Double?
    let market_cap: Double?
    let market_cap_dominance: Double?
    let fully_diluted_market_cap: Double?
    let last_updated: String?
}
