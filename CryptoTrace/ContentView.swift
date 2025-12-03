//
//  ContentView.swift
//  FinanceTracker
//
//  Created by Owner on 11/30/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var vm = ListingsViewModel()
    @State private var searchText = ""
    @State private var sort: SortOption = .rank
    @Environment(\.appTheme) private var theme

    enum SortOption: String, CaseIterable, Identifiable {
        case rank = "Rank"
        case price = "Price"
        case marketCap = "Market Cap"
        case change24h = "24h Change"

        var id: String { rawValue }
    }

    private var filteredAndSorted: [Crypto] {
        var list = vm.cryptos

        // Filter
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            list = list.filter { $0.name.lowercased().contains(q) || $0.symbol.lowercased().contains(q) }
        }

        // Sort
        switch sort {
        case .rank:
            list.sort { ($0.cmc_rank ?? Int.max) < ($1.cmc_rank ?? Int.max) }
        case .price:
            list.sort { ($0.usd?.price ?? 0) > ($1.usd?.price ?? 0) }
        case .marketCap:
            list.sort { ($0.usd?.market_cap ?? 0) > ($1.usd?.market_cap ?? 0) }
        case .change24h:
            list.sort { ($0.usd?.percent_change_24h ?? -Double.infinity) > ($1.usd?.percent_change_24h ?? -Double.infinity) }
        }

        return list
    }

    private var topMovers: [Crypto] {
        vm.cryptos
            .sorted {
                abs($0.usd?.percent_change_24h ?? 0) > abs($1.usd?.percent_change_24h ?? 0)
            }
            .prefix(10)
            .map { $0 }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.background.ignoresSafeArea()

                VStack(spacing: 12) {
                    if !topMovers.isEmpty {
                        TopMoversView(coins: topMovers, logoURL: vm.logoURL(for:))
                            .padding(.horizontal)
                            .padding(.top, 4)
                    }

                    Picker("Sort", selection: $sort) {
                        ForEach(SortOption.allCases) { opt in
                            Text(opt.rawValue).tag(opt)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .tint(theme.accent)

                    Group {
                        if vm.isLoading && vm.cryptos.isEmpty {
                            Spacer(minLength: 0)
                        } else if let message = vm.errorMessage, vm.cryptos.isEmpty {
                            Spacer()
                            VStack(spacing: 12) {
                                Text("Error")
                                    .font(.headline)
                                Text(message)
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(theme.secondaryText)
                            }
                            .padding()
                            Spacer()
                        } else {
                            List {
                                ForEach(Array(filteredAndSorted.enumerated()), id: \.element.id) { index, coin in
                                    NavigationLink {
                                        CoinDetailView(
                                            coin: coin,
                                            logoURL: vm.logoURL(for: coin.id)
                                        )
                                    } label: {
                                        CoinListRow(coin: coin, logoURL: vm.logoURL(for: coin.id))
                                    }
                                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                                    .listRowBackground(theme.surface)
                                    .onAppear {
                                        let backingCount = vm.cryptos.count
                                        if index == filteredAndSorted.count - 1 && backingCount >= 50 {
                                            Task { await vm.loadMore() }
                                        }
                                    }
                                }

                                if vm.isLoadingMore {
                                    HStack {
                                        Spacer()
                                        ProgressView().padding(.vertical, 12)
                                        Spacer()
                                    }
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(theme.surface)
                                }
                            }
                            .listStyle(.insetGrouped)
                            .scrollContentBackground(.hidden) // prevent default white background
                            .refreshable { await vm.load() }
                            .animation(.easeInOut(duration: 0.25), value: filteredAndSorted.map(\.id))
                        }
                    }
                }

                if vm.isLoading && vm.cryptos.isEmpty {
                    LoadingOverlay()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .navigationTitle("Crypto Tracker")
            .toolbarBackground(theme.surface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic))
        }
        .task { await vm.load() }
    }
}

private struct TopMoversView: View {
    let coins: [Crypto]
    let logoURL: (Int) -> URL?
    @Environment(\.appTheme) private var theme

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(coins) { coin in
                    NavigationLink {
                        CoinDetailView(coin: coin, logoURL: logoURL(coin.id))
                    } label: {
                        TopMoverCard(coin: coin, logoURL: logoURL(coin.id))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 8)
        }
        .tint(theme.accent)
    }
}

private struct TopMoverCard: View {
    let coin: Crypto
    let logoURL: URL?
    @Environment(\.appTheme) private var theme

    var body: some View {
        let price = coin.usd?.price
        let change = coin.usd?.percent_change_24h ?? 0

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                AsyncLogo(url: logoURL)
                    .frame(width: 28, height: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(coin.symbol)
                        .font(.headline)
                    if let rank = coin.cmc_rank {
                        Text("#\(rank)")
                            .font(.caption2)
                            .foregroundStyle(theme.secondaryText)
                    }
                }
                Spacer()
            }

            Text(formatPrice(price))
                .font(.title3).bold()

            HStack(spacing: 6) {
                Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                Text(formatChange(change))
            }
            .font(.subheadline)
            .foregroundStyle(change >= 0 ? .green : .red)

            ChangeBar(percent: change)
                .frame(height: 6)
                .animation(Animation.spring(response: 0.6, dampingFraction: 0.7), value: change)
        }
        .padding(12)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(theme.surfaceStroke, lineWidth: 1)
        )
    }
}

private struct CoinListRow: View {
    let coin: Crypto
    let logoURL: URL?

    @State private var points: [Double] = []
    @Environment(\.appTheme) private var theme

    var body: some View {
        let price = coin.usd?.price ?? 0
        let change = coin.usd?.percent_change_24h ?? 0
        let color: Color = change >= 0 ? .green : .red

        HStack(alignment: .center, spacing: 12) {
            AsyncLogo(url: logoURL)
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if let rank = coin.cmc_rank {
                        Text("#\(rank)")
                            .font(.caption).bold()
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(theme.subtleFill, in: Capsule())
                            .foregroundStyle(theme.secondaryText)
                            .fixedSize()
                            .layoutPriority(2)
                    }

                    Text(coin.name)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .layoutPriority(1)
                        .minimumScaleFactor(0.8)
                }
                Text(coin.symbol)
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 6) {
                SparklineView(points: points, tint: color.opacity(0.9))
                    .frame(width: 86, height: 24)
                    .opacity(points.isEmpty ? 0.3 : 1)

                Text(formatPrice(price))
                    .font(.headline)
                    .minimumScaleFactor(0.9)
                    .overlay(
                        Rectangle()
                            .fill(theme.accent.opacity(0.25))
                            .frame(height: 2)
                            .offset(y: 10),
                        alignment: .bottom
                    )
            }
        }
        .contentShape(Rectangle())
        .task(id: coin.id) {
            // Switch sparkline to 1h change and 60 samples (1 per minute)
            points = SparklineBuilder.series(current: price, percentChange: coin.usd?.percent_change_1h, count: 60)
        }
    }
}

private struct LoadingOverlay: View {
    @State private var spin = false
    @Environment(\.colorScheme) private var scheme
    @Environment(\.appTheme) private var theme

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "bitcoinsign.circle.fill")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundStyle(.orange)
                    .rotationEffect(.degrees(spin ? 360 : 0))
                    .animation(.linear(duration: 1.2).repeatForever(autoreverses: false), value: spin)

                Text("Fetching markets…")
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryText)
            }
        }
        .onAppear { spin = true }
    }
}

#Preview {
    ContentView()
}
