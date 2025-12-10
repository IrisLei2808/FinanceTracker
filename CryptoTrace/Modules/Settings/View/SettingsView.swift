import SwiftUI

struct SettingsView: View {
    @AppStorage("settings.theme") private var theme: Theme = .system
    @AppStorage("settings.currency") private var currency: Currency = .usd
    @AppStorage("settings.refreshInterval") private var refreshInterval: RefreshInterval = .fifteen
    @AppStorage("settings.defaultSort") private var defaultSort: DefaultSort = .rank
    @AppStorage("settings.showTopMovers") private var showTopMovers: Bool = true
    @AppStorage("settings.haptics") private var hapticsEnabled: Bool = true
    @State private var notificationsEnabled: Bool = false // placeholder

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("App")) {
                    Picker("Theme", selection: $theme) {
                        ForEach(Theme.allCases) { t in
                            Text(t.title).tag(t)
                        }
                    }
                    Picker("Currency", selection: $currency) {
                        ForEach(Currency.allCases) { c in
                            Text(c.title).tag(c)
                        }
                    }
                    Picker("Refresh", selection: $refreshInterval) {
                        ForEach(RefreshInterval.allCases) { r in
                            Text(r.title).tag(r)
                        }
                    }
                    Toggle("Haptics", isOn: $hapticsEnabled)
                }

                Section(header: Text("Data")) {
                    Picker("Default Sort", selection: $defaultSort) {
                        ForEach(DefaultSort.allCases) { s in
                            Text(s.title).tag(s)
                        }
                    }
                    Toggle("Show Top Movers", isOn: $showTopMovers)
                }

                Section(header: Text("Notifications")) {
                    Toggle("Price Alerts", isOn: $notificationsEnabled)
                    Text("Enable to receive price movement alerts. (Placeholder)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersionString()).foregroundStyle(.secondary)
                    }
                    Link(destination: URL(string: "https://irislei2808.github.io/cryptotrace-legal/privacy-policy")!) {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }
                    Link(destination: URL(string: "https://irislei2808.github.io/cryptotrace-legal/terms-of-service")!) {
                        Label("Terms of Service", systemImage: "doc.plaintext")
                    }
                    Link(destination: URL(string: "https://irislei2808.github.io/cryptotrace-legal/disclaimer")!) {
                        Label("Disclaimer", systemImage: "exclamationmark.bubble")
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }

    private func appVersionString() -> String {
        let ver = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(ver) (\(build))"
    }
}

// MARK: - Settings Types

enum Theme: String, CaseIterable, Identifiable, Codable {
    case system, light, dark
    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

enum Currency: String, CaseIterable, Identifiable, Codable {
    case usd, eur, gbp, jpy
    var id: String { rawValue }
    var title: String {
        rawValue.uppercased()
    }
}

enum RefreshInterval: String, CaseIterable, Identifiable, Codable {
    case five = "5s", fifteen = "15s", thirty = "30s", minute = "1m", off = "Manual"
    var id: String { rawValue }
    var title: String { rawValue }
    var seconds: TimeInterval? {
        switch self {
        case .five: return 5
        case .fifteen: return 15
        case .thirty: return 30
        case .minute: return 60
        case .off: return nil
        }
    }
}

enum DefaultSort: String, CaseIterable, Identifiable, Codable {
    case rank = "Rank", price = "Price", marketCap = "Market Cap", change24h = "24h Change"
    var id: String { rawValue }
    var title: String { rawValue }
}
