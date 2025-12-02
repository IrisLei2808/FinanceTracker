import Foundation
import Combine

@MainActor
final class FinnhubNewsViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var articles: [FinnhubNewsArticle] = []
    @Published var category: Category = .general

    enum Category: String, CaseIterable, Identifiable {
        case general, business, technology, crypto, forex, merger
        var id: String { rawValue }
        var display: String {
            switch self {
            case .general: return "General"
            case .business: return "Business"
            case .technology: return "Tech"
            case .crypto: return "Crypto"
            case .forex: return "Forex"
            case .merger: return "M&A"
            }
        }
    }

    // Use your provided token. For production, store securely.
    private let service = FinnhubNewsService(token: "d4n1hk9r01qsn6g911ugd4n1hk9r01qsn6g911v0")

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let list = try await service.fetch(category: category.rawValue)
            articles = list
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            articles = []
        }
    }
}

