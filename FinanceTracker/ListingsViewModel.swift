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

    // Pagination state
    private let pageSize = 50
    private var hasLoadedSecondPage = false
    @Published var isLoadingMore = false

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        hasLoadedSecondPage = false // reset paging on full reload
        defer { isLoading = false }

        do {
            var items = try await api.latestListings(start: 1, limit: pageSize, convert: "USD")
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
            cryptos = []
            logoURLs = [:]
        }
    }

    func loadMore() async {
        // Only one extra page (to reach ~100) and avoid concurrent calls
        guard !hasLoadedSecondPage, !isLoading, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let start = pageSize + 1 // 51
            let more = try await api.latestListings(start: start, limit: pageSize, convert: "USD")

            // Merge + dedupe by id
            let existingIDs = Set(cryptos.map { $0.id })
            let newOnes = more.filter { !existingIDs.contains($0.id) }

            var merged = cryptos + newOnes
            // Sort by rank for consistency
            merged.sort { (a, b) in
                (a.cmc_rank ?? Int.max) < (b.cmc_rank ?? Int.max)
            }
            cryptos = merged

            // Fetch logos for the new IDs and merge into logoURLs
            let newIDs = newOnes.map { $0.id }
            if !newIDs.isEmpty {
                let infoMap = try await api.info(forIDs: newIDs)
                var updates = logoURLs
                for (id, info) in infoMap {
                    if let logo = info.logo {
                        updates[id] = logo
                    }
                }
                logoURLs = updates
            }

            hasLoadedSecondPage = true
        } catch {
            // Don’t flip the flag so user can try again by scrolling
            if case CoinMarketCapAPIError.badStatus(let code) = error {
                errorMessage = "Server returned status \(code)."
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }

    func logoURL(for id: Int) -> URL? {
        guard let str = logoURLs[id] else { return nil }
        return URL(string: str)
    }
}

