import SwiftUI

struct AddEditHoldingView: View {
    let coins: [Crypto]
    let logoURL: (Int) -> URL?
    let initial: Holding?
    let onSave: (Holding) -> Void

    @Environment(\.dismiss) private var dismiss

    // Form state
    @State private var selectedCoinId: Int = 0
    @State private var amountText: String = ""
    @State private var costText: String = ""
    @State private var note: String = ""
    @State private var date: Date = Date()

    // Validation
    private var amount: Double? { Double(amountText.replacingOccurrences(of: ",", with: "")) }
    private var costPerUnit: Double? { Double(costText.replacingOccurrences(of: ",", with: "")) }
    private var isValid: Bool {
        selectedCoinId != 0 && (amount ?? 0) > 0 && (costPerUnit ?? 0) > 0
    }

    init(coins: [Crypto], logoURL: @escaping (Int) -> URL?, initial: Holding?, onSave: @escaping (Holding) -> Void) {
        self.coins = coins
        self.logoURL = logoURL
        self.initial = initial
        self.onSave = onSave
        // _@State vars will be set in .onAppear to have access to coins/initial
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Asset")) {
                    Picker("Coin", selection: $selectedCoinId) {
                        Text("Select a coin").tag(0)
                        ForEach(coins) { c in
                            HStack {
                                Text(c.symbol).bold()
                                Text(c.name).foregroundStyle(.secondary)
                            }
                            .tag(c.id)
                        }
                    }

                    if let coin = coins.first(where: { $0.id == selectedCoinId }) {
                        HStack(spacing: 12) {
                            AsyncLogo(url: logoURL(coin.id))
                                .frame(width: 28, height: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(coin.name).font(.subheadline).bold()
                                Text(coin.symbol).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if let price = coin.usd?.price {
                                Text("Now " + formatPriceNoCents(price))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section(header: Text("Position")) {
                    TextField("Amount", text: $amountText)
                        .keyboardType(.decimalPad)

                    TextField("Cost per unit", text: $costText)
                        .keyboardType(.decimalPad)

                    DatePicker("Date", selection: $date, displayedComponents: [.date])
                }

                Section(header: Text("Notes (optional)")) {
                    TextField("Add a note", text: $note, axis: .vertical)
                        .lineLimit(1...3)
                }

                if let amt = amount, let cpu = costPerUnit, amt > 0, cpu > 0 {
                    let total = amt * cpu
                    Section {
                        HStack {
                            Text("Cost basis")
                            Spacer()
                            Text(formatPriceNoCents(total)).bold()
                        }
                    }
                }
            }
            .navigationTitle(initial == nil ? "Add Holding" : "Edit Holding")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        save()
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear {
                // Prefill for edit or set sensible defaults
                if let h = initial {
                    selectedCoinId = h.coinId
                    amountText = cleanNumber(h.amount)
                    costText = cleanNumber(h.costPerUnit)
                    note = h.note ?? ""
                    if let d = h.date { date = d }
                } else {
                    // Default to first coin if available
                    selectedCoinId = coins.first?.id ?? 0
                }
            }
        }
    }

    private func save() {
        guard isValid, let amt = amount, let cpu = costPerUnit else { return }
        if var existing = initial {
            // Preserve ID for edit
            existing.coinId = selectedCoinId
            existing.amount = amt
            existing.costPerUnit = cpu
            existing.note = note.isEmpty ? nil : note
            existing.date = date
            onSave(existing)
        } else {
            let new = Holding(
                coinId: selectedCoinId,
                amount: amt,
                costPerUnit: cpu,
                note: note.isEmpty ? nil : note,
                date: date
            )
            onSave(new)
        }
        dismiss()
    }

    private func cleanNumber(_ value: Double) -> String {
        // Avoid trailing zeros; up to 8 decimals for crypto amounts/costs
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 8
        return f.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

#Preview {
    let coins: [Crypto] = [
        Crypto(id: 1, name: "Bitcoin", symbol: "BTC", slug: "bitcoin", cmc_rank: 1, last_updated: nil, quote: ["USD": FiatQuote(price: 42000, volume_24h: nil, volume_change_24h: nil, percent_change_1h: 0.3, percent_change_24h: -2.4, percent_change_7d: 5.1, market_cap: 800_000_000_000, market_cap_dominance: nil, fully_diluted_market_cap: nil, last_updated: nil)]),
        Crypto(id: 1027, name: "Ethereum", symbol: "ETH", slug: "ethereum", cmc_rank: 2, last_updated: nil, quote: ["USD": FiatQuote(price: 2200, volume_24h: nil, volume_change_24h: nil, percent_change_1h: -0.1, percent_change_24h: 1.2, percent_change_7d: 3.3, market_cap: 300_000_000_000, market_cap_dominance: nil, fully_diluted_market_cap: nil, last_updated: nil)])
    ]
    return AddEditHoldingView(
        coins: coins,
        logoURL: { _ in nil },
        initial: nil
    ) { _ in }
}
