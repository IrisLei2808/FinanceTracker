import Foundation
import SwiftUI

// Centralized currency conversion without extra API calls.
// We assume all incoming values are USD-based (as fetched from APIs) and convert to the user-selected currency.
private struct LocalRates {
    // Base: 1 USD -> X target currency units
    // You can tweak these defaults or later persist updated rates in UserDefaults without needing network at runtime.
    static var defaults: [Currency: Double] = [
        .usd: 1.0,    // 1 USD = 1.00 USD
        .eur: 0.92,   // 1 USD ≈ 0.92 EUR
        .gbp: 0.80,   // 1 USD ≈ 0.80 GBP
        .jpy: 147.0   // 1 USD ≈ 147.00 JPY
    ]

    // Optional persisted overrides (so you can update rates occasionally and keep them offline)
    static var persisted: [Currency: Double] {
        get {
            guard let data = UserDefaults.standard.data(forKey: "local.fx.rates"),
                  let decoded = try? JSONDecoder().decode([String: Double].self, from: data)
            else { return [:] }
            var out: [Currency: Double] = [:]
            for (k, v) in decoded {
                if let c = Currency(rawValue: k) { out[c] = v }
            }
            return out
        }
        set {
            let dict = Dictionary(uniqueKeysWithValues: newValue.map { ($0.key.rawValue, $0.value) })
            if let data = try? JSONEncoder().encode(dict) {
                UserDefaults.standard.set(data, forKey: "local.fx.rates")
            }
        }
    }

    static func rate(for currency: Currency) -> Double {
        // Use persisted override if present, else default
        if let r = persisted[currency] { return r }
        return defaults[currency] ?? 1.0
    }
}

// Currency metadata helpers
private func currencyCode(_ c: Currency) -> String {
    switch c {
    case .usd: return "USD"
    case .eur: return "EUR"
    case .gbp: return "GBP"
    case .jpy: return "JPY"
    }
}

private func fractionDigits(for code: String, value: Double) -> Int {
    // For crypto-style display: more precision under 1. Otherwise use typical 2 for fiat, except JPY often 0.
    switch code {
    case "JPY":
        return value >= 1 ? 0 : 2
    default:
        return value >= 1 ? 2 : 6
    }
}

// Convert a USD value to the selected currency using local rates.
private func convertUSDToSelected(_ usd: Double, selected: Currency) -> Double {
    let r = LocalRates.rate(for: selected) // units of selected per 1 USD
    return usd * r
}

// MARK: - Public formatting functions used across the app

func formatPrice(_ value: Double?) -> String {
    guard let value else { return "--" }

    // Read selected currency from Settings
    let selectedRaw = UserDefaults.standard.string(forKey: "settings.currency") ?? Currency.usd.rawValue
    let selected = Currency(rawValue: selectedRaw) ?? .usd

    // Convert from USD (API base) to selected currency locally
    let converted = convertUSDToSelected(value, selected: selected)

    let f = NumberFormatter()
    f.numberStyle = .currency
    f.currencyCode = currencyCode(selected)
    f.maximumFractionDigits = fractionDigits(for: f.currencyCode ?? "USD", value: converted)
    return f.string(from: NSNumber(value: converted)) ?? "\(converted)"
}

func formatChange(_ value: Double) -> String {
    let f = NumberFormatter()
    f.numberStyle = .percent
    f.maximumFractionDigits = 2
    // API returns percent points; convert to fraction for formatter
    return f.string(from: NSNumber(value: value / 100.0)) ?? "\(value)%"
}

func shortenCurrency(_ value: Double) -> String {
    // We receive USD-based amounts (e.g., market caps). Convert, then shorten.
    let selectedRaw = UserDefaults.standard.string(forKey: "settings.currency") ?? Currency.usd.rawValue
    let selected = Currency(rawValue: selectedRaw) ?? .usd

    let converted = convertUSDToSelected(value, selected: selected)

    let absVal = abs(converted)
    let sign = converted < 0 ? "-" : ""
    let (div, suffix): (Double, String) = {
        switch absVal {
        case 1_000_000_000_000...: return (1_000_000_000_000, "T")
        case 1_000_000_000...:     return (1_000_000_000, "B")
        case 1_000_000...:         return (1_000_000, "M")
        case 1_000...:             return (1_000, "K")
        default:                    return (1, "")
        }
    }()
    let num = absVal / div

    let f = NumberFormatter()
    f.numberStyle = .currency
    f.currencyCode = currencyCode(selected)
    // Fewer decimals for large magnitudes
    f.maximumFractionDigits = num >= 100 ? 0 : 2

    let formatted = f.string(from: NSNumber(value: num)) ?? "\(num)"
    return "\(sign)\(formatted)\(suffix)"
}

