//
//  ListingsViewModel.swift
//  FinanceTracker
//
//  Created by Owner on 11/30/25.
//

import Foundation
import Combine

@MainActor
final class ListingsViewModel: ObservableObject {
    @Published var cryptos: [Crypto] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // id -> logo URL string
    @Published private(set) var logoURLs: [Int: String] = [:]

    private let api = CoinMarketCapAPI(apiKey: "9831eaab718a45bc836def372d080d33")

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        do {
            var items = try await api.latestListings(start: 1, limit: 50, convert: "USD")
            // Sort by rank if available
            items.sort { (a, b) in
                (a.cmc_rank ?? Int.max) < (b.cmc_rank ?? Int.max)
            }
            cryptos = items

            // Fetch logos for these IDs
            let ids = items.map { $0.id }
            let infoMap = try await api.info(forIDs: ids)
            var newLogos: [Int: String] = [:]
            for (id, info) in infoMap {
                if let logo = info.logo {
                    newLogos[id] = logo
                }
            }
            logoURLs = newLogos
        } catch {
            if case CoinMarketCapAPIError.badStatus(let code) = error {
                errorMessage = "Server returned status \(code)."
            } else {
                errorMessage = error.localizedDescription
            }
        }
        isLoading = false
    }

    func logoURL(for id: Int) -> URL? {
        guard let str = logoURLs[id] else { return nil }
        return URL(string: str)
    }
}
