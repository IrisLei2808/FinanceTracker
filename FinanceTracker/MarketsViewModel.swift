import Foundation
import Combine

@MainActor
final class MarketsViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var tickers: [CGTickersResponse.Ticker] = []
    @Published var errorMessage: String?

    private let gecko = CoinGeckoAPI()

    func load(for coin: Crypto) async {
        // Markets data disabled (CoinGecko removed)
        isLoading = false
        errorMessage = "Markets data is not available."
    }
}
