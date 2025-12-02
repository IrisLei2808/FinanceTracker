import SwiftUI

enum PriceRange: String, CaseIterable, Identifiable {
    case h1 = "1H", d1 = "1D", w1 = "1W", m1 = "1M", y1 = "1Y"
    var id: String { rawValue }
}

struct CoinDetailView: View {
    let coin: Crypto
    let logoURL: URL?

    @EnvironmentObject private var watchlist: WatchlistStore

    @State private var selectedTab: Int = 0
    @State private var range: PriceRange = .d1
    @StateObject private var historyVM = PriceHistoryViewModel()
    // Removed CommunityViewModel and MarketsViewModel
    @StateObject private var newsVM = NewsViewModel()

    private let tabs: [String] = ["Overview","News"]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header

                // Tabs
                SegmentedTabs(tabs: tabs, selection: $selectedTab)

                if selectedTab == 0 {
                    overview
                } else {
                    newsView
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .navigationTitle(coin.symbol)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await historyVM.loadHistory(for: coin.id, range: range) { coin }
            await newsVM.loadFiltered(for: coin)
        }
        .onChange(of: range) { _, newValue in
            Task { await historyVM.loadHistory(for: coin.id, range: newValue) { coin } }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            AsyncImage(url: logoURL) { phase in
                switch phase {
                case .empty: Circle().fill(.gray.opacity(0.15))
                case .success(let img): img.resizable().scaledToFit()
                case .failure: Image(systemName: "bitcoinsign.circle").resizable().scaledToFit().foregroundStyle(.secondary)
                @unknown default: EmptyView()
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(coin.name).font(.headline)
                    if let rank = coin.cmc_rank {
                        Text("#\(rank)")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.gray.opacity(0.15), in: Capsule())
                            .foregroundStyle(.secondary)
                    }
                }
                Text(coin.symbol).font(.subheadline).foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                watchlist.toggle(coin.id)
            } label: {
                Image(systemName: watchlist.contains(coin.id) ? "star.fill" : "star")
                    .foregroundStyle(watchlist.contains(coin.id) ? .yellow : .primary)
                    .imageScale(.large)
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(watchlist.contains(coin.id) ? "Remove from Watchlist" : "Add to Watchlist")
        }
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Price and 24h change
            let price = coin.usd?.price
            let change = coin.usd?.percent_change_24h ?? 0

            VStack(alignment: .leading, spacing: 8) {
                Text(formatPrice(price))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                Text(formatChange(change))
                    .font(.subheadline).bold()
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background((change >= 0 ? Color.green.opacity(0.15) : Color.red.opacity(0.15)), in: Capsule())
                    .foregroundStyle(change >= 0 ? .green : .red)
            }

            // Chart
            VStack(alignment: .leading, spacing: 12) {
                if historyVM.isLoading {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12).fill(.gray.opacity(0.1))
                        ProgressView()
                    }
                    .frame(height: 240)
                } else if let points = historyVM.points, !points.isEmpty {
                    EnhancedLineChart(points: points, accent: change >= 0 ? .green : .red)
                        .frame(height: 240)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.gray.opacity(0.05))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(.gray.opacity(0.12), lineWidth: 1)
                        )
                        .animation(.easeInOut(duration: 0.3), value: points)
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12).fill(.gray.opacity(0.08))
                        Text(historyVM.errorMessage ?? "No data")
                            .foregroundStyle(.secondary)
                    }
                    .frame(height: 240)
                }

                // Range picker
                HStack(spacing: 8) {
                    ForEach(PriceRange.allCases) { r in
                        Button {
                            range = r
                        } label: {
                            Text(r.rawValue)
                                .font(.subheadline).bold()
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(range == r ? Color.accentColor : Color.clear, in: Capsule())
                                .overlay(
                                    Capsule().stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                                )
                                .foregroundStyle(range == r ? Color.white : Color.primary)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                    Image(systemName: "slider.horizontal.3")
                        .foregroundStyle(.secondary)
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .foregroundStyle(.secondary)
                }
            }

            // Quick period performance (if available)
            HStack {
                if let w = coin.usd?.percent_change_7d {
                    periodStat(title: "Week", value: w)
                }
                if let d = coin.usd?.percent_change_24h {
                    periodStat(title: "Day", value: d)
                }
                if let h = coin.usd?.percent_change_1h {
                    periodStat(title: "Hour", value: h)
                }
            }

            // Stats
            VStack(alignment: .leading, spacing: 8) {
                Text("Statistics").font(.headline)
                statRow(title: "Market Cap", value: coin.usd?.market_cap)
                statRow(title: "Volume 24h", value: coin.usd?.volume_24h)
                statRow(title: "FDV", value: coin.usd?.fully_diluted_market_cap)
            }
            .padding()
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var newsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("News").font(.headline)
            if newsVM.isLoading {
                ProgressView().frame(maxWidth: .infinity)
            } else if !newsVM.items.isEmpty {
                VStack(spacing: 8) {
                    ForEach(newsVM.items) { item in
                        Link(destination: URL(string: item.link)!) {
                            HStack(alignment: .top, spacing: 10) {
                                if let img = item.imageURL, let url = URL(string: img) {
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .empty: Color.gray.opacity(0.15)
                                        case .success(let image): image.resizable().scaledToFill()
                                        case .failure: Image(systemName: "photo").resizable().scaledToFit().foregroundStyle(.secondary)
                                        @unknown default: EmptyView()
                                        }
                                    }
                                    .frame(width: 60, height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.title).font(.subheadline).bold()
                                    HStack(spacing: 8) {
                                        Text(item.source)
                                        if let date = item.published {
                                            Text(date.formatted(date: .abbreviated, time: .shortened))
                                        }
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding()
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else if let msg = newsVM.errorMessage {
                Text(msg).foregroundStyle(.secondary)
            } else {
                Text("No recent news mentioning \(coin.symbol)").foregroundStyle(.secondary)
            }
        }
    }

    private func periodStat(title: String, value: Double) -> some View {
        VStack(alignment: .leading) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(formatChange(value))
                .font(.subheadline).bold()
                .foregroundStyle(value >= 0 ? .green : .red)
        }
        .padding(.trailing, 16)
    }

    private func statRow(title: String, value: Double?) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(shortenCurrency(value ?? .nan))
                .foregroundStyle(.secondary)
        }
        .font(.subheadline)
    }
}

// MARK: - Small components (SegmentedTabs, EnhancedLineChart, AsyncLogo, ChangePill, ChangeBar) remain unchanged

#Preview {
    ContentView()
}
