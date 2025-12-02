import Foundation

enum MoralisAPIError: Error, LocalizedError {
    case invalidURL
    case badStatus(Int)
    case decoding(Error)
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .badStatus(let code): return "Bad HTTP status: \(code)"
        case .decoding(let err): return "Failed to decode response: \(err.localizedDescription)"
        case .transport(let err): return "Network error: \(err.localizedDescription)"
        }
    }
}

// Top-level response is an array
struct MoralisTopCollection: Codable, Identifiable {
    // Compose a more unique and stable id to avoid duplicates in ForEach
    // Use address + rank + title when available; otherwise include image as a tiebreaker;
    // fallback to UUID to guarantee uniqueness if all are nil.
    var id: String {
        let addr = collection_address ?? "noaddr"
        let rankStr = rank.map { "#\($0)" } ?? "norank"
        let title = (collection_title?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? "notitle"
        let image = (collection_image?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? "noimg"
        // Include multiple fields to reduce collision risk across modes and pages
        return [addr, rankStr, title, image].joined(separator: "|")
    }

    let rank: Int?
    let collection_title: String?
    let collection_image: String?
    let floor_price_usd: String?
    let floor_price_24hr_percent_change: String?
    let market_cap_usd: String?
    let market_cap_24hr_percent_change: String?
    let volume_usd: String?
    let volume_24hr_percent_change: String?
    let collection_address: String?
    let floor_price: String?
    let floor_price_usd_24hr_percent_change: String?

    // Helpers to coerce string numbers -> Double
    var floorPriceUSD: Double? { MoralisAPI.toDouble(floor_price_usd) }
    var floorChange24h: Double? { MoralisAPI.toDouble(floor_price_24hr_percent_change) }
    var marketCapUSD: Double? { MoralisAPI.toDouble(market_cap_usd) }
    var marketCapChange24h: Double? { MoralisAPI.toDouble(market_cap_24hr_percent_change) }
    var volumeUSD: Double? { MoralisAPI.toDouble(volume_usd) }
    var volumeChange24h: Double? { MoralisAPI.toDouble(volume_24hr_percent_change) }
}

struct MoralisAPI {
    var apiKey: String

    func topCollections() async throws -> [MoralisTopCollection] {
        guard let url = URL(string: "https://deep-index.moralis.io/api/v2.2/market-data/nfts/top-collections") else {
            throw MoralisAPIError.invalidURL
        }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue(apiKey, forHTTPHeaderField: "X-API-Key")

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else { throw MoralisAPIError.badStatus(-1) }
            guard 200..<300 ~= http.statusCode else {
                throw MoralisAPIError.badStatus(http.statusCode)
            }
            do {
                let decoder = JSONDecoder()
                return try decoder.decode([MoralisTopCollection].self, from: data)
            } catch {
                // If decoding fails, you can print raw for debugging
                // print(String(data: data, encoding: .utf8) ?? "")
                throw MoralisAPIError.decoding(error)
            }
        } catch let e as MoralisAPIError {
            throw e
        } catch {
            throw MoralisAPIError.transport(error)
        }
    }

    // NEW: Hottest collections (trading volume)
    func hottestCollections() async throws -> [MoralisTopCollection] {
        guard let url = URL(string: "https://deep-index.moralis.io/api/v2.2/market-data/nfts/hottest-collections") else {
            throw MoralisAPIError.invalidURL
        }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue(apiKey, forHTTPHeaderField: "X-API-Key")

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else { throw MoralisAPIError.badStatus(-1) }
            guard 200..<300 ~= http.statusCode else {
                throw MoralisAPIError.badStatus(http.statusCode)
            }
            do {
                let decoder = JSONDecoder()
                return try decoder.decode([MoralisTopCollection].self, from: data)
            } catch {
                throw MoralisAPIError.decoding(error)
            }
        } catch let e as MoralisAPIError {
            throw e
        } catch {
            throw MoralisAPIError.transport(error)
        }
    }

    static func toDouble(_ s: String?) -> Double? {
        guard let s = s else { return nil }
        return Double(s.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
