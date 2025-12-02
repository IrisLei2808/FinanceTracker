import Foundation

enum CoinGeckoAPIError: Error, LocalizedError {
    case invalidURL
    case badStatus(Int)
    case decoding(Error)
    case transport(Error)
    case notFound
    case apiMessage(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .badStatus(let code):
            return "Bad HTTP status: \(code)"
        case .decoding(let err):
            return "Failed to decode response: \(err.localizedDescription)"
        case .transport(let err):
            return "Network error: \(err.localizedDescription)"
        case .notFound:
            return "Not found"
        case .apiMessage(let message):
            return message
        }
    }
}

struct CoinGeckoAPI {
    // Cache CMC id -> Gecko id in-memory to avoid repeated lookups
    static var idCache: [Int: String] = [:]

    // Resolve CoinGecko id for a given CMC crypto
    // Strategy: prefer slug match via /search, fallback to name/symbol match.
    func resolveCoinGeckoID(for coin: Crypto) async throws -> String {
        if let cached = Self.idCache[coin.id] { return cached }

        // Use slug if available, otherwise try name/symbol query
        let query = coin.slug ?? coin.name
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.coingecko.com/api/v3/search?query=\(encoded)") else {
            throw CoinGeckoAPIError.invalidURL
        }

        do {
            let (data, resp) = try await URLSession.shared.data(from: url)
            guard let http = resp as? HTTPURLResponse else { throw CoinGeckoAPIError.badStatus(-1) }
            guard 200..<300 ~= http.statusCode else { throw CoinGeckoAPIError.badStatus(http.statusCode) }
            let decoded = try JSONDecoder().decode(CGSearchResponse.self, from: data)

            // Try exact slug match first (if slug exists)
            if let slug = coin.slug?.lowercased(),
               let match = decoded.coins.first(where: { $0.id == slug || $0.api_symbol == slug || $0.symbol.lowercased() == coin.symbol.lowercased() && $0.name.lowercased() == coin.name.lowercased() }) {
                Self.idCache[coin.id] = match.id
                return match.id
            }

            // Fallback: best-effort by symbol then name
            if let match = decoded.coins.first(where: { $0.symbol.lowercased() == coin.symbol.lowercased() }) ??
                           decoded.coins.first(where: { $0.name.lowercased() == coin.name.lowercased() }) ??
                           decoded.coins.first {
                Self.idCache[coin.id] = match.id
                return match.id
            }

            throw CoinGeckoAPIError.notFound
        } catch let e as CoinGeckoAPIError {
            throw e
        } catch {
            throw CoinGeckoAPIError.transport(error)
        }
    }

    // Historical market chart
    // days: 1, 7, 30, 365
    func marketChart(geckoID: String, vsCurrency: String = "usd", days: Int) async throws -> CGMarketChartResponse {
        var comps = URLComponents(string: "https://api.coingecko.com/api/v3/coins/\(geckoID)/market_chart")
        comps?.queryItems = [
            URLQueryItem(name: "vs_currency", value: vsCurrency),
            URLQueryItem(name: "days", value: String(days))
        ]
        guard let url = comps?.url else { throw CoinGeckoAPIError.invalidURL }

        do {
            let (data, resp) = try await URLSession.shared.data(from: url)
            guard let http = resp as? HTTPURLResponse else { throw CoinGeckoAPIError.badStatus(-1) }
            guard 200..<300 ~= http.statusCode else {
                // Try to parse API error message even on non-2xx
                if let message = Self.extractAPIServerMessage(from: data) {
                    throw CoinGeckoAPIError.apiMessage(message)
                }
                throw CoinGeckoAPIError.badStatus(http.statusCode)
            }
            do {
                return try JSONDecoder().decode(CGMarketChartResponse.self, from: data)
            } catch {
                // Attempt to decode API error envelope for better message
                if let message = Self.extractAPIServerMessage(from: data) {
                    throw CoinGeckoAPIError.apiMessage(message)
                }
                // Debug aid: uncomment to print raw response
                // if let s = String(data: data, encoding: .utf8) { print("market_chart raw:", s) }
                throw CoinGeckoAPIError.decoding(error)
            }
        } catch let e as CoinGeckoAPIError {
            throw e
        } catch {
            throw CoinGeckoAPIError.transport(error)
        }
    }

    // Coin detail (community metrics + links)
    func coinDetail(geckoID: String) async throws -> CGCoinDetail {
        guard let url = URL(string: "https://api.coingecko.com/api/v3/coins/\(geckoID)?localization=false&tickers=false&market_data=false&community_data=true&developer_data=false&sparkline=false") else {
            throw CoinGeckoAPIError.invalidURL
        }
        do {
            let (data, resp) = try await URLSession.shared.data(from: url)
            guard let http = resp as? HTTPURLResponse else { throw CoinGeckoAPIError.badStatus(-1) }
            guard 200..<300 ~= http.statusCode else {
                if let message = Self.extractAPIServerMessage(from: data) {
                    throw CoinGeckoAPIError.apiMessage(message)
                }
                throw CoinGeckoAPIError.badStatus(http.statusCode)
            }
            do {
                return try JSONDecoder().decode(CGCoinDetail.self, from: data)
            } catch {
                if let message = Self.extractAPIServerMessage(from: data) {
                    throw CoinGeckoAPIError.apiMessage(message)
                }
                throw CoinGeckoAPIError.decoding(error)
            }
        } catch let e as CoinGeckoAPIError {
            throw e
        } catch {
            throw CoinGeckoAPIError.transport(error)
        }
    }

    // Tickers (markets/exchanges)
    func tickers(geckoID: String, page: Int = 1) async throws -> CGTickersResponse {
        var comps = URLComponents(string: "https://api.coingecko.com/api/v3/coins/\(geckoID)/tickers")
        comps?.queryItems = [
            URLQueryItem(name: "page", value: String(page))
        ]
        guard let url = comps?.url else { throw CoinGeckoAPIError.invalidURL }
        do {
            let (data, resp) = try await URLSession.shared.data(from: url)
            guard let http = resp as? HTTPURLResponse else { throw CoinGeckoAPIError.badStatus(-1) }
            guard 200..<300 ~= http.statusCode else {
                if let message = Self.extractAPIServerMessage(from: data) {
                    throw CoinGeckoAPIError.apiMessage(message)
                }
                throw CoinGeckoAPIError.badStatus(http.statusCode)
            }
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                return try decoder.decode(CGTickersResponse.self, from: data)
            } catch {
                if let message = Self.extractAPIServerMessage(from: data) {
                    throw CoinGeckoAPIError.apiMessage(message)
                }
                // Debug aid: uncomment to print raw response
                // if let s = String(data: data, encoding: .utf8) { print("tickers raw:", s) }
                throw CoinGeckoAPIError.decoding(error)
            }
        } catch let e as CoinGeckoAPIError {
            throw e
        } catch {
            throw CoinGeckoAPIError.transport(error)
        }
    }

    // MARK: - Helpers

    // CoinGecko often returns either:
    // { "error": "message" }
    // or
    // { "status": { "error_code": 429, "error_message": "..." } }
    private static func extractAPIServerMessage(from data: Data) -> String? {
        // Try "error" string
        struct ErrorString: Decodable { let error: String }
        if let msg = try? JSONDecoder().decode(ErrorString.self, from: data).error, !msg.isEmpty {
            return msg
        }
        // Try "status" envelope
        struct StatusEnvelope: Decodable {
            struct Status: Decodable {
                let error_code: Int?
                let error_message: String?
            }
            let status: Status
        }
        if let env = try? JSONDecoder().decode(StatusEnvelope.self, from: data),
           let message = env.status.error_message, !message.isEmpty {
            return message
        }
        return nil
    }
}
