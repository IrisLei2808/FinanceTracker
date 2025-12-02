import SwiftUI

struct PortfolioView: View {
    @EnvironmentObject private var portfolio: PortfolioStore
    @StateObject private var listings = ListingsViewModel()

    @State private var showingAdd = false
    @State private var editing: Holding?
    @State private var searchText = ""
    @State private var showAI = false
    @State private var isEditingMode = false

    private var prices: [Int: Double] { portfolio.priceMap(from: listings.cryptos) }

    // Derived totals
    private var totalValue: Double { portfolio.totalMarketValue(with: prices) }
    private var totalCost: Double { portfolio.totalCostBasis }
    private var totalPL: Double { totalValue - totalCost }
    private var dayPL: Double { portfolio.dayChange(with: listings.cryptos, prices: prices) }

    // Filtered holdings (by coin name/symbol)
    private var filteredHoldings: [Holding] {
        guard !searchText.isEmpty else { return portfolio.holdings }
        let q = searchText.lowercased()
        return portfolio.holdings.filter { h in
            if let c = listings.cryptos.first(where: { $0.id == h.coinId }) {
                return c.name.lowercased().contains(q) || c.symbol.lowercased().contains(q)
            }
            return false
        }
    }

    // Allocation data with colors
    private var allocationData: [(coinId: Int, value: Double, percent: Double, color: Color, symbol: String)] {
        let allocs = portfolio.allocations(with: prices)
        let total = max(allocs.map(\.1).reduce(0, +), 1e-9)
        return allocs.map { (id, val) in
            let pct = val / total
            let symbol = listings.cryptos.first(where: { $0.id == id })?.symbol ?? "#\(id)"
            return (id, val, pct, stableColor(for: id), symbol)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if listings.isLoading && listings.cryptos.isEmpty {
                    ProgressView("Loading prices…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if portfolio.holdings.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            summaryHeader
                            allocationSection
                            holdingsSection
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .refreshable { await listings.load() }
                }
            }
            .navigationTitle("Portfolio")
            // Toolbar icons removed per request
        }
        .task { await listings.load() }
        .sheet(isPresented: $showingAdd) {
            AddEditHoldingView(
                coins: listings.cryptos,
                logoURL: listings.logoURL(for:),
                initial: nil
            ) { newHolding in
                portfolio.add(newHolding)
            }
        }
        .sheet(item: $editing) { hold in
            AddEditHoldingView(
                coins: listings.cryptos,
                logoURL: listings.logoURL(for:),
                initial: hold
            ) { updated in
                portfolio.update(updated)
            }
        }
        // Keep AI sheet wiring; no top icon triggers it now. You can remove if not needed.
        .sheet(isPresented: $showAI) {
            AIAnalysisView(cryptos: listings.cryptos)
        }
        .searchable(text: $searchText)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.pie")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No holdings yet")
                .font(.title2).bold()
            Text("Add your first coin to start tracking allocation and P/L.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button {
                showingAdd = true
            } label: {
                Label("Add Investment", systemImage: "plus.circle")
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Summary Header (Pro)

    private var summaryHeader: some View {
        VStack(spacing: 10) {
            // Top line: Net Worth + inline actions (Add, Edit)
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Net Worth")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(formatPrice(totalValue))
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(.blue) // primary metric uses blue
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)
                }

                Spacer()

                // Inline actions next to Net Worth
                HStack(spacing: 8) {
                    Button {
                        showingAdd = true
                    } label: {
                        Label("Add", systemImage: "plus")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        isEditingMode.toggle()
                    } label: {
                        Image(systemName: isEditingMode ? "checkmark.circle.fill" : "pencil.circle")
                    }
                    .buttonStyle(.bordered)
                }
            }

            // Second line: P/L and Day P/L
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Unrealized P/L")
                        .font(.caption).foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        Image(systemName: totalPL >= 0 ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill")
                        Text((totalPL >= 0 ? "+" : "") + formatPrice(totalPL))
                    }
                    .font(.headline)
                    .foregroundStyle(totalPL >= 0 ? .green : .red)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                }

                Spacer()

                HStack(spacing: 6) {
                    Image(systemName: "clock")
                    Text("Day")
                        .font(.caption).foregroundStyle(.secondary)
                    Text((dayPL >= 0 ? "+" : "") + formatPrice(dayPL))
                        .font(.subheadline).bold()
                        .foregroundStyle(dayPL >= 0 ? .green : .red)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.gray.opacity(0.10), in: Capsule())
            }
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.gray.opacity(0.12), lineWidth: 1)
        )
    }

    // MARK: - Allocation

    private var allocationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Allocation").font(.headline)
                Spacer()
                if totalValue > 0 {
                    Text("Total: " + formatPrice(totalValue))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if allocationData.isEmpty || totalValue <= 0 {
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(.gray.opacity(0.08))
                    Text("No allocation yet").foregroundStyle(.secondary)
                }
                .frame(height: 160)
            } else {
                VStack(spacing: 14) {
                    // Donut without the surrounding square/card background
                    DonutChart(
                        segments: allocationData.map { d in
                            DonutChart.Segment(id: d.coinId, value: d.value, label: d.symbol, color: d.color)
                        }
                    )
                    .frame(height: 200)
                    .padding(.bottom, 16) // extra space below the donut to avoid overlap

                    // Legend
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(allocationData, id: \.coinId) { item in
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(item.color)
                                        .frame(width: 10, height: 10)
                                    Text(item.symbol)
                                        .font(.caption).bold()
                                    Text(String(format: "%.1f%%", item.percent * 100))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.gray.opacity(0.10), in: Capsule())
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                    .padding(.top, 2)
                }
            }
        }
    }

    // MARK: - Holdings

    private var holdingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Holdings").font(.headline)
                Spacer()
                if isEditingMode {
                    Button {
                        showingAdd = true
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                }
            }

            VStack(spacing: 8) {
                ForEach(filteredHoldings) { h in
                    let coin = listings.cryptos.first(where: { $0.id == h.coinId })
                    let color = stableColor(for: h.coinId)
                    HoldingRow(
                        holding: h,
                        coin: coin,
                        logoURL: listings.logoURL(for: h.coinId),
                        currentPrice: prices[h.coinId] ?? 0,
                        accent: color,
                        isEditingMode: isEditingMode
                    ) {
                        editing = h
                    } onDelete: {
                        portfolio.remove(h.id)
                    }
                }
            }
            .padding(10)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12).stroke(.gray.opacity(0.12), lineWidth: 1)
            )
        }
    }

    // Deterministic stable color for each coinId (moved down per request)
    private func stableColor(for id: Int) -> Color {
        // A curated professional palette
        let palette: [Color] = [
            Color(hue: 0.58, saturation: 0.70, brightness: 0.95), // blue
            Color(hue: 0.40, saturation: 0.65, brightness: 0.90), // green
            Color(hue: 0.07, saturation: 0.75, brightness: 0.95), // orange
            Color(hue: 0.84, saturation: 0.45, brightness: 0.95), // purple/pink
            Color(hue: 0.52, saturation: 0.45, brightness: 0.95), // teal
            Color(hue: 0.96, saturation: 0.55, brightness: 0.95), // red-ish (accent only)
            Color(hue: 0.16, saturation: 0.55, brightness: 0.95), // amber
            Color(hue: 0.68, saturation: 0.45, brightness: 0.95), // indigo
            Color(hue: 0.48, saturation: 0.35, brightness: 0.95), // mint
            Color(hue: 0.03, saturation: 0.35, brightness: 0.90)  // brown-ish
        ]
        // Deterministic index
        let idx = abs((id &* 2654435761) % Int(UInt32(palette.count)))
        return palette[Int(idx)]
    }
}

// MARK: - Holding Row (Pro)

private struct HoldingRow: View {
    let holding: Holding
    let coin: Crypto?
    let logoURL: URL?
    let currentPrice: Double
    let accent: Color
    let isEditingMode: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        let value = holding.amount * currentPrice
        let pl = value - holding.costBasisTotal
        let pct = holding.costBasisTotal > 0 ? (pl / holding.costBasisTotal) * 100.0 : 0

        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle().fill(accent.opacity(0.18))
                AsyncLogo(url: logoURL)
                    .padding(4)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(coin?.symbol ?? "—")
                        .font(.subheadline).bold()
                        .lineLimit(1)
                    Text(coin?.name ?? "Coin")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                HStack(spacing: 8) {
                    Text("\(holding.amount, specifier: "%.4f")")
                        .font(.caption).bold()
                        .foregroundStyle(.primary)
                    Text("@")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(formatPrice(holding.costPerUnit))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .lineLimit(1)
            }
            .layoutPriority(1)

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Text(formatPrice(value))
                    .font(.subheadline).bold()
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .foregroundStyle(.primary)

                HStack(spacing: 6) {
                    Image(systemName: pl >= 0 ? "arrow.up.right" : "arrow.down.right")
                    Text(formatPrice(pl))
                    Text(formatChange(pct))
                        .foregroundStyle(.secondary)
                }
                .font(.caption).bold()
                .foregroundStyle(pl >= 0 ? .green : .red)
                .fixedSize(horizontal: true, vertical: false)

                Text("Now " + formatPrice(currentPrice))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if isEditingMode {
                Menu {
                    Button {
                        onEdit()
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .imageScale(.large)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { onDelete() } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading) {
            Button { onEdit() } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.orange)
        }
    }
}

// MARK: - Add/Edit Holding

private struct AddEditHoldingView: View {
    let coins: [Crypto]
    let logoURL: (Int) -> URL?
    let initial: Holding?
    let onSave: (Holding) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var selectedCoinId: Int = 0
    @State private var amount: String = ""
    @State private var costPerUnit: String = ""
    @State private var note: String = ""
    @State private var date: Date = Date()

    var isEditing: Bool { initial != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Asset")) {
                    Picker("Coin", selection: $selectedCoinId) {
                        ForEach(coins) { c in
                            HStack {
                                Text(c.symbol).bold()
                                Text(c.name).foregroundStyle(.secondary)
                            }
                            .tag(c.id)
                        }
                    }
                }

                Section(header: Text("Position")) {
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)
                    TextField("Cost per unit (USD)", text: $costPerUnit)
                        .keyboardType(.decimalPad)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    TextField("Note", text: $note)
                }

                if let sel = coins.first(where: { $0.id == selectedCoinId }) {
                    let price = sel.usd?.price ?? 0
                    Section(header: Text("Reference")) {
                        HStack {
                            Text("Current price")
                            Spacer()
                            Text(formatPrice(price)).foregroundStyle(.secondary)
                        }
                        HStack {
                            Text("Logo")
                            Spacer()
                            AsyncLogo(url: logoURL(sel.id))
                                .frame(width: 24, height: 24)
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Holding" : "Add Holding")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isEditing ? "Save" : "Add") {
                        if let h = buildHolding() {
                            onSave(h)
                            dismiss()
                        }
                    }
                    .disabled(buildHolding() == nil)
                }
            }
            .onAppear {
                if let initial {
                    selectedCoinId = initial.coinId
                    amount = formatNumber(initial.amount)
                    costPerUnit = formatNumber(initial.costPerUnit)
                    note = initial.note ?? ""
                    date = initial.date ?? Date()
                } else {
                    selectedCoinId = coins.first?.id ?? 0
                }
            }
        }
    }

    private func buildHolding() -> Holding? {
        guard selectedCoinId != 0,
              let amt = Double(amount.replacingOccurrences(of: ",", with: ".")),
              let cpu = Double(costPerUnit.replacingOccurrences(of: ",", with: ".")),
              amt > 0, cpu > 0 else { return nil }

        if var existing = initial {
            existing.coinId = selectedCoinId
            existing.amount = amt
            existing.costPerUnit = cpu
            existing.note = note.isEmpty ? nil : note
            existing.date = date
            return existing
        } else {
            return Holding(coinId: selectedCoinId, amount: amt, costPerUnit: cpu, note: note.isEmpty ? nil : note, date: date)
        }
    }

    private func formatNumber(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 8
        return f.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

// MARK: - Donut Chart with external colors

private struct DonutChart: View {
    struct Segment: Identifiable {
        var id: Int
        var value: Double
        var label: String
        var color: Color
    }

    let segments: [Segment]

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let lineWidth = size * 0.18
            let radius = size / 2
            let total = max(segments.reduce(0) { $0 + $1.value }, 1e-9)
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)

            // Precompute angles
            let segmentsWithAngles: [(segment: Segment, start: Angle, end: Angle)] = {
                var cumulative = Angle(degrees: -90)
                var result: [(Segment, Angle, Angle)] = []
                for s in segments {
                    let sweep = Angle(degrees: (s.value / total) * 360.0)
                    let start = cumulative
                    let end = cumulative + sweep
                    result.append((s, start, end))
                    cumulative = end
                }
                return result
            }()

            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.gray.opacity(0.15), lineWidth: lineWidth)

                // Segments
                ForEach(segmentsWithAngles, id: \.segment.id) { item in
                    DonutSlice(
                        center: center,
                        radius: radius,
                        lineWidth: lineWidth,
                        start: item.start,
                        end: item.end
                    )
                    .fill(item.segment.color)
                }

                // Center label
                VStack(spacing: 4) {
                    Text("Allocation")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(segments.isEmpty ? "—" : "\(segments.count) assets")
                        .font(.subheadline).bold()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

private struct DonutSlice: Shape {
    let center: CGPoint
    let radius: CGFloat
    let lineWidth: CGFloat
    let start: Angle
    let end: Angle

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let innerR = radius - lineWidth / 2
        p.addArc(center: center, radius: innerR + lineWidth / 2, startAngle: start, endAngle: end, clockwise: false)
        return p.strokedPath(StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
    }
}

#Preview {
    PortfolioView()
        .environmentObject(PortfolioStore())
}
