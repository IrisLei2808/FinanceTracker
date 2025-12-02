import Foundation

enum FinnhubNewsError: Error, LocalizedError {
    case invalidURL
    case badStatus(Int)
    case decoding(Error)
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .badStatus(let code): return "Bad HTTP status: \(code)"
        case .decoding(let err): return "Failed to decode news: \(err.localizedDescription)"
        case .transport(let err): return "Network error: \(err.localizedDescription)"
        }
    }
}

struct FinnhubNewsArticle: Codable, Identifiable {
    let category: String?
    let datetime: TimeInterval
    let headline: String
    let id: Int
    let image: String?
    let related: String?
    let source: String
    let summary: String?
    let url: String

    var publishedDate: Date { Date(timeIntervalSince1970: datetime) }
}

struct FinnhubNewsService {
    let token: String

    func fetch(category: String = "general") async throws -> [FinnhubNewsArticle] {
        var comps = URLComponents(string: "https://finnhub.io/api/v1/news")
        comps?.queryItems = [
            URLQueryItem(name: "category", value: category),
            URLQueryItem(name: "token", value: token)
        ]
        guard let url = comps?.url else { throw FinnhubNewsError.invalidURL }

        do {
            let (data, resp) = try await URLSession.shared.data(from: url)
            guard let http = resp as? HTTPURLResponse else { throw FinnhubNewsError.badStatus(-1) }
            guard 200..<300 ~= http.statusCode else { throw FinnhubNewsError.badStatus(http.statusCode) }
            do {
                let decoded = try JSONDecoder().decode([FinnhubNewsArticle].self, from: data)
                return decoded.sorted { $0.datetime > $1.datetime }
            } catch {
                throw FinnhubNewsError.decoding(error)
            }
        } catch let e as FinnhubNewsError {
            throw e
        } catch {
            throw FinnhubNewsError.transport(error)
        }
    }
}

