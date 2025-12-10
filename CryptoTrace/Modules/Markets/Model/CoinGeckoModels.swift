import Foundation

// Search
struct CGSearchResponse: Codable {
    struct Item: Codable {
        let id: String            // gecko id (e.g., "bitcoin")
        let name: String
        let symbol: String
        let market_cap_rank: Int?
        let api_symbol: String
        let thumb: String?
        let large: String?
    }
    let coins: [Item]
}

// Market chart
struct CGMarketChartResponse: Codable {
    // arrays of [timestamp(ms), value]
    let prices: [[Double]]
    let market_caps: [[Double]]?
    let total_volumes: [[Double]]?
}

// Coin detail (community)
struct CGCoinDetail: Codable {
    struct CommunityData: Codable {
        let twitter_followers: Double?
        let reddit_subscribers: Double?
        let reddit_average_posts_48h: Double?
        let reddit_average_comments_48h: Double?
        let telegram_channel_user_count: Double?
    }
    struct Links: Codable {
        let homepage: [String]?
        let subreddit_url: String?
        let repos_url: [String: [String]]?
        let twitter_screen_name: String?
        let blockchain_site: [String]?
        let official_forum_url: [String]?
        let chat_url: [String]?
    }
    struct Image: Codable {
        let thumb: String?
        let small: String?
        let large: String?
    }

    let id: String
    let symbol: String
    let name: String
    let community_data: CommunityData?
    let links: Links?
    let image: Image?
}

// Tickers (markets/exchanges)
struct CGTickersResponse: Codable {
    struct Market: Codable {
        let name: String?
        let identifier: String?
        let has_trading_incentive: Bool?
    }

    struct Ticker: Codable, Identifiable {
        // Provide a stable id by combining market + base/target + timestamp if available
        var id: String {
            let m = market?.identifier ?? market?.name ?? "market"
            let b = base ?? "base"
            let t = target ?? "target"
            let ts = String(timestamp?.timeIntervalSince1970 ?? 0)
            return [m, b, t, ts].joined(separator: "|")
        }

        let base: String?
        let target: String?
        let market: Market?
        let last: Double?
        let volume: Double?
        let bid_ask_spread_percentage: Double?
        let converted_last: [String: Double]?
        let converted_volume: [String: Double]?
        let trust_score: String?
        let timestamp: Date?
        let last_traded_at: Date?
        let last_fetch_at: Date?
        let is_anomaly: Bool?
        let is_stale: Bool?
        let trade_url: String?
        let token_info_url: String?
        let coin_id: String?
        let target_coin_id: String?

        enum CodingKeys: String, CodingKey {
            case base, target, market, last, volume
            case bid_ask_spread_percentage
            case converted_last, converted_volume
            case trust_score, timestamp
            case last_traded_at, last_fetch_at
            case is_anomaly, is_stale
            case trade_url, token_info_url
            case coin_id, target_coin_id
        }
    }

    let name: String?
    let tickers: [Ticker]
}

// Custom decoder configuration if needed elsewhere:
// let decoder = JSONDecoder()
// decoder.dateDecodingStrategy = .iso8601
