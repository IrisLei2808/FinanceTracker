import Foundation
import Combine

@MainActor
final class CommunityViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var detail: CGCoinDetail?
    @Published var errorMessage: String?
    @Published var detailName: String?

    private let gecko = CoinGeckoAPI()

    func load(for coin: Crypto) async {
        // Community data disabled (CoinGecko removed)
        isLoading = false
        detail = nil
        detailName = coin.name
        errorMessage = "Community data is not available."
    }
}
