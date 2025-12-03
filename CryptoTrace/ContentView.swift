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
                VStack(spacing: 12) {
                    // Top Movers carousel
                    if !topMovers.isEmpty {
                        TopMoversView(coins: topMovers, logoURL: vm.logoURL(for:))
                            .padding(.horizontal)
                            .padding(.top, 4)
                    }

                    // Sort control
                    Picker("Sort", selection: $sort) {
                        ForEach(SortOption.allCases) { opt in
                            Text(opt.rawValue).tag(opt)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // Main list
                    Group {
                        if vm.isLoading && vm.cryptos.isEmpty {
                            // Space is now managed by overlay; keep a small placeholder to avoid layout jumps
                            Spacer(minLength: 0)
                        } else if let message = vm.errorMessage, vm.cryptos.isEmpty {
                            Spacer()
                            VStack(spacing: 12) {
                                Text("Error")
                                    .font(.headline)
                                Text(message)
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(.secondary)
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
                                            .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                                    }
                                    .onAppear {
                                        // If you added pagination earlier, keep this trigger; otherwise it’s harmless.
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
                                }
                            }
                            .listStyle(.plain)
                            .refreshable { await vm.load() }
                            .animation(.easeInOut(duration: 0.25), value: filteredAndSorted.map(\.id))
                        }
                    }
                }

                // Full-screen animated overlay while initial data is loading
                if vm.isLoading && vm.cryptos.isEmpty {
                    LoadingOverlay()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .navigationTitle("Crypto Tracker")
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic))
        }
        .task { await vm.load() }
    }
}

private struct TopMoversView: View {
    let coins: [Crypto]
    let logoURL: (Int) -> URL?

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
    }
}

private struct TopMoverCard: View {
    let coin: Crypto
    let logoURL: URL?

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
                            .foregroundStyle(.secondary)
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
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.gray.opacity(0.12), lineWidth: 1)
        )
    }
}

// Updated row layout: ensure rank capsule stays readable even with long names.
private struct CoinListRow: View {
    let coin: Crypto
    let logoURL: URL?

    @State private var points: [Double] = []

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
                            .background(Color.gray.opacity(0.15), in: Capsule())
                            .foregroundStyle(.secondary)
                            // Ensure rank doesn’t get squeezed by long names:
                            .fixedSize()                // keep intrinsic size
                            .layoutPriority(2)          // rank wins space over name
                    }

                    // Name will truncate before rank shrinks
                    Text(coin.name)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .layoutPriority(1)
                        .minimumScaleFactor(0.8)     // allow a bit of scale before truncating
                }
                Text(coin.symbol)
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                            .fill(color.opacity(0.3))
                            .frame(height: 2)
                            .offset(y: 10),
                        alignment: .bottom
                    )
            }
        }
        .contentShape(Rectangle())
        .task(id: coin.id) {
            points = SparklineBuilder.series(current: price, percentChange: coin.usd?.percent_change_24h)
        }
    }
}

// A lightweight animated full-screen overlay to avoid blank screen on cold start
private struct LoadingOverlay: View {
    @State private var spin = false
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            // Match system launch background
            (scheme == .dark ? Color.black : Color.white)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "bitcoinsign.circle.fill")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundStyle(.orange)
                    .rotationEffect(.degrees(spin ? 360 : 0))
                    .animation(.linear(duration: 1.2).repeatForever(autoreverses: false), value: spin)

                Text("Fetching markets…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear { spin = true }
    }
}

#Preview {
    ContentView()
}
