import Foundation
import Combine

@MainActor
final class NFTCollectionsViewModel: ObservableObject {
    enum Mode: String, CaseIterable, Identifiable {
        case top = "Top"
        case hottest = "Hottest"

        var id: String { rawValue }
    }

    @Published var mode: Mode = .top
    @Published var collections: [MoralisTopCollection] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // Simple in-memory caches per mode
    private var cachedTop: [MoralisTopCollection]?
    private var cachedHottest: [MoralisTopCollection]?

    // Use your provided Moralis key. Consider moving to Secrets/Info.plist for production.
    private let api = MoralisAPI(apiKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJub25jZSI6IjI3OTJiN2Y1LWVlYWYtNGNhYy05ZWU3LTAzNWI4YTI3NGUzZSIsIm9yZ0lkIjoiNDA5NzMxIiwidXNlcklkIjoiNDIxMDQ5IiwidHlwZUlkIjoiNmFlMjA3YzQtM2JhMS00OGZhLWFiMjQtNDNjMzRmZTcyZmJkIiwidHlwZSI6IlBST0pFQ1QiLCJpYXQiOjE3Mjc1MDE2MDcsImV4cCI6NDg4MzI2MTYwN30.fPZ15q0_rIbEGMLV9Fs1trzASBHPhporYOlc9Ew-r10")

    // Public API: load respecting cache
    func load() async {
        await load(force: false)
    }

    // Force reload bypasses cache
    func forceReload() async {
        await load(force: true)
    }

    private func load(force: Bool) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            // Serve from cache if available and not forcing
            if !force {
                switch mode {
                case .top:
                    if let cachedTop { self.collections = cachedTop; return }
                case .hottest:
                    if let cachedHottest { self.collections = cachedHottest; return }
                }
            }

            let items: [MoralisTopCollection]
            switch mode {
            case .top:
                items = try await api.topCollections()
                // Sort by rank ascending if present
                let sorted = items.sorted { (a, b) in
                    (a.rank ?? Int.max) < (b.rank ?? Int.max)
                }
                self.collections = sorted
                self.cachedTop = sorted
            case .hottest:
                items = try await api.hottestCollections()
                // Sort by volume descending if present
                let sorted = items.sorted { (a, b) in
                    (a.volumeUSD ?? 0) > (b.volumeUSD ?? 0)
                }
                self.collections = sorted
                self.cachedHottest = sorted
            }
        } catch {
            if let e = error as? LocalizedError, let msg = e.errorDescription {
                self.errorMessage = msg
            } else {
                self.errorMessage = error.localizedDescription
            }
            self.collections = []
        }
    }
}
