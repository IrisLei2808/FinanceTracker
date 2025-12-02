import Foundation

func formatPrice(_ value: Double?) -> String {
    guard let value else { return "--" }
    let f = NumberFormatter()
    f.numberStyle = .currency
    f.currencyCode = "USD"
    f.maximumFractionDigits = value >= 1 ? 2 : 6
    return f.string(from: NSNumber(value: value)) ?? "$\(value)"
}

func formatChange(_ value: Double) -> String {
    let f = NumberFormatter()
    f.numberStyle = .percent
    f.maximumFractionDigits = 2
    // API returns percent points; convert to fraction for formatter
    return f.string(from: NSNumber(value: value / 100.0)) ?? "\(value)%"
}

func shortenCurrency(_ value: Double) -> String {
    // 1,234 -> 1.23K, 1,234,567 -> 1.23M, etc.
    let absVal = abs(value)
    let sign = value < 0 ? "-" : ""
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
    f.currencyCode = "USD"
    f.maximumFractionDigits = num >= 100 ? 0 : 2
    let formatted = f.string(from: NSNumber(value: num)) ?? "\(num)"
    return "\(sign)\(formatted)\(suffix)"
}
