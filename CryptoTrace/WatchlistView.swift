import SwiftUI

struct WatchlistView: View {
    @EnvironmentObject private var watchlist: WatchlistStore
    @StateObject private var listings = ListingsViewModel()
    @State private var searchText = ""

    // Personalization
    @AppStorage("watchlist.showChange") private var showChange: Bool = true
    @AppStorage("watchlist.rowStyle") private var rowStyleRaw: String = WatchlistRowStyle.rich.rawValue
    @AppStorage("watchlist.pins") private var pinnedIDsRaw: String = "" // comma-separated Ints
    @State private var appearedIDs: Set<Int> = []

    private var rowStyle: WatchlistRowStyle {
        get { WatchlistRowStyle(rawValue: rowStyleRaw) ?? .rich }
        set { rowStyleRaw = newValue.rawValue }
    }
    private var pinnedIDs: Set<Int> {
        get { Set(pinnedIDsRaw.split(separator: ",").compactMap { Int($0) }) }
        set { pinnedIDsRaw = newValue.sorted().map(String.init).joined(separator: ",") }
    }

    // Resolve watchlisted IDs to full Crypto models from current listings
    private var watchlistedCoins: [Crypto] {
        let set = watchlist.ids
        let matched = listings.cryptos.filter { set.contains($0.id) }
        if searchText.isEmpty { return matched }
        let q = searchText.lowercased()
        return matched.filter { $0.name.lowercased().contains(q) || $0.symbol.lowercased().contains(q) }
    }

    // Derived sections
    private var pinnedCoins: [Crypto] {
        let ids = pinnedIDs
        return watchlistedCoins.filter { ids.contains($0.id) }
            .sorted { ($0.cmc_rank ?? Int.max) < ($1.cmc_rank ?? Int.max) }
    }
    private var unpinnedCoins: [Crypto] {
        let ids = pinnedIDs
        return watchlistedCoins.filter { !ids.contains($0.id) }
            .sorted { ($0.cmc_rank ?? Int.max) < ($1.cmc_rank ?? Int.max) }
    }

    // Quick stats for header
    private var advancersCount: Int {
        watchlistedCoins.filter { ($0.usd?.percent_change_24h ?? 0) > 0 }.count
    }
    private var declinersCount: Int {
        watchlistedCoins.filter { ($0.usd?.percent_change_24h ?? 0) < 0 }.count
    }
    private var topMover: Crypto? {
        watchlistedCoins.max(by: { abs($0.usd?.percent_change_24h ?? 0) < abs($1.usd?.percent_change_24h ?? 0) })
    }

    var body: some View {
        NavigationStack {
            Group {
                if watchlist.ids.isEmpty {
                    emptyState
                } else if listings.isLoading && listings.cryptos.isEmpty {
                    loadingState
                } else {
                    List {
                        if !watchlistedCoins.isEmpty {
                            Section {
                                headerStats
                                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                                    .listRowBackground(Color.clear)
                            }
                        }

                        if !pinnedCoins.isEmpty {
                            Section("Pinned") {
                                ForEach(pinnedCoins) { coin in
                                    row(for: coin)
                                }
                            }
                        }

                        Section(unpinnedSectionTitle) {
                            ForEach(unpinnedCoins) { coin in
                                row(for: coin)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .refreshable { await listings.load() }
                    .overlay {
                        if !listings.isLoading, watchlistedCoins.isEmpty {
                            VStack(spacing: 8) {
                                Text("No matches")
                                    .font(.headline)
                                Text("Try a different search.")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .animation(.easeOut(duration: 0.3), value: watchlistedCoins.map(\.id))
                }
            }
            .navigationTitle("Watchlist")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        Picker("Row Style", selection: $rowStyleRaw) {
                            ForEach(WatchlistRowStyle.allCases) { style in
                                Label(style.title, systemImage: style.icon).tag(style.rawValue)
                            }
                        }
                        Toggle(isOn: $showChange) {
                            Label("Show 24h Change", systemImage: "arrow.up.right")
                        }
                        Button {
                            appearedIDs.removeAll()
                        } label: {
                            Label("Reset Row Animations", systemImage: "sparkles")
                        }
                        Divider()
                        Button {
                            Task { await listings.load() }
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .searchable(text: $searchText)
        .task { await listings.load() }
    }

    // MARK: - Components

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "star")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Watchlist")
                .font(.title2).bold()
            Text("Tap the star on any coin to save it here.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading coins…")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var headerStats: some View {
        HStack(spacing: 12) {
            StatCard(
                title: "Breadth",
                subtitle: "\(advancersCount) ↑  •  \(declinersCount) ↓",
                color: advancersCount >= declinersCount ? .green : .red,
                symbol: advancersCount >= declinersCount ? "chart.line.uptrend.xyaxis" : "chart.line.downtrend.xyaxis"
            )
            if let mover = topMover {
                let ch = mover.usd?.percent_change_24h ?? 0
                StatCard(
                    title: "Top Mover",
                    subtitle: "\(mover.symbol)  \(formatChange(ch))",
                    color: ch >= 0 ? .green : .red,
                    symbol: ch >= 0 ? "arrow.up.forward" : "arrow.down.forward"
                )
            } else {
                StatCard(
                    title: "Top Mover",
                    subtitle: "—",
                    color: .gray,
                    symbol: "bolt"
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var unpinnedSectionTitle: String {
        if searchText.isEmpty {
            return "All"
        } else {
            return "Results"
        }
    }

    @ViewBuilder
    private func row(for coin: Crypto) -> some View {
        NavigationLink {
            CoinDetailView(
                coin: coin,
                logoURL: listings.logoURL(for: coin.id)
            )
        } label: {
            switch rowStyle {
            case .compact:
                WatchlistSimpleRow(
                    coin: coin,
                    logoURL: listings.logoURL(for: coin.id)
                )
                .opacity(appearedIDs.contains(coin.id) ? 1 : 0)
                .offset(y: appearedIDs.contains(coin.id) ? 0 : 10)
                .onAppear { animateAppear(coin.id) }
            case .rich:
                WatchlistRichRow(
                    coin: coin,
                    logoURL: listings.logoURL(for: coin.id),
                    showChange: showChange
                )
                .opacity(appearedIDs.contains(coin.id) ? 1 : 0)
                .offset(y: appearedIDs.contains(coin.id) ? 0 : 10)
                .onAppear { animateAppear(coin.id) }
            }
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                watchlist.remove(coin.id)
            } label: {
                Label("Remove", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading) {
            let isPinned = pinnedIDs.contains(coin.id)
            Button {
                togglePin(coin.id)
            } label: {
                Label(isPinned ? "Unpin" : "Pin", systemImage: isPinned ? "pin.slash" : "pin")
            }
            .tint(.orange)
        }
    }

    private func animateAppear(_ id: Int) {
        guard !appearedIDs.contains(id) else { return }
        let delay = Double(appearedIDs.count) * 0.03
        withAnimation(.easeOut(duration: 0.35).delay(delay)) {
            appearedIDs.insert(id)
        }
    }

    private func togglePin(_ id: Int) {
        var set = Set(pinnedIDsRaw.split(separator: ",").compactMap { Int($0) })
        if set.contains(id) {
            set.remove(id)
        } else {
            set.insert(id)
        }
        pinnedIDsRaw = set.sorted().map(String.init).joined(separator: ",")
    }
}

// MARK: - Row styles

private enum WatchlistRowStyle: String, CaseIterable, Identifiable {
    case compact, rich
    var id: String { rawValue }
    var title: String {
        switch self {
        case .compact: return "Compact"
        case .rich: return "Rich"
        }
    }
    var icon: String {
        switch self {
        case .compact: return "list.bullet"
        case .rich: return "rectangle.grid.1x2"
        }
    }
}

// Existing simple row (icon, full name, price)
private struct WatchlistSimpleRow: View {
    let coin: Crypto
    let logoURL: URL?

    var body: some View {
        let price = coin.usd?.price

        HStack(spacing: 12) {
            AsyncLogo(url: logoURL)
                .frame(width: 36, height: 36)

            Text(coin.name)
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 8)

            Text(formatPrice(price))
                .font(.headline)
                .minimumScaleFactor(0.9)
                .multilineTextAlignment(.trailing)
        }
        .contentShape(Rectangle())
    }
}

// Rich row with 24h + 1h changes and price
private struct WatchlistRichRow: View {
    let coin: Crypto
    let logoURL: URL?
    let showChange: Bool

    @State private var points: [Double] = []

    var body: some View {
        let price = coin.usd?.price ?? 0
        let change24h = coin.usd?.percent_change_24h ?? 0
        let change1h = coin.usd?.percent_change_1h ?? 0

        HStack(spacing: 12) {
            // Icon
            AsyncLogo(url: logoURL)
                .frame(width: 36, height: 36)

            // Name + symbol
            VStack(alignment: .leading, spacing: 2) {
                Text(coin.name)
                    .font(.headline)
                    .lineLimit(1)
                Text(coin.symbol)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            // Changes + price (trailing)
            VStack(alignment: .trailing, spacing: 6) {
                
                Text(formatPrice(price))
                    .font(.headline)
                    .minimumScaleFactor(0.9)
                    .multilineTextAlignment(.trailing)
                
                if showChange {
                    HStack(spacing: 6) {
                        ChangePill(title: "24h", value: change24h)
                            .fixedSize()
                        ChangePill(title: "1h", value: change1h)
                            .fixedSize()
                    }
                }

               
            }
        }
        .contentShape(Rectangle())
        .task(id: coin.id) {
            // Keep building points, but switch to 1h with 60 samples for consistency if sparkline is re-enabled
            points = SparklineBuilder.series(current: price, percentChange: coin.usd?.percent_change_1h, count: 60)
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let subtitle: String
    let color: Color
    let symbol: String

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(color.opacity(0.15))
                Image(systemName: symbol)
                    .foregroundStyle(color)
                    .imageScale(.medium)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(subtitle)
                    .font(.subheadline).bold()
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.gray.opacity(0.12), lineWidth: 1)
        )
    }
}

#Preview {
    WatchlistView()
        .environmentObject(WatchlistStore())
}
