import Foundation

enum Secrets {
    // Centralized CoinMarketCap API key used across the app.
    // Consider moving this to a secure location for production (e.g., Keychain, configuration files, or CI secrets).
    static let cmcAPIKey: String = "9831eaab718a45bc836def372d080d33"
}
