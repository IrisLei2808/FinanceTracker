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
                        Spacer()
                        ProgressView("Loading...")
                        Spacer()
                    } else if let message = vm.errorMessage, vm.cryptos.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            Text("Error")
                                .font(.headline)
                            Text(message)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.secondary)
                            Button {
                                Task { await vm.load() }
                            } label: {
                                Label("Retry", systemImage: "arrow.clockwise")
                            }
                        }
                        .padding()
                        Spacer()
                    } else {
                        List {
                            ForEach(Array(filteredAndSorted.enumerated()), id: \.element.id) { (_, coin) in
                                NavigationLink {
                                    CoinDetailView(
                                        coin: coin,
                                        logoURL: vm.logoURL(for: coin.id)
                                    )
                                } label: {
                                    CoinRichRowView(coin: coin, logoURL: vm.logoURL(for: coin.id))
                                        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                                }
                            }
                        }
                        .listStyle(.plain)
                        .refreshable { await vm.load() }
                        .animation(.easeInOut(duration: 0.25), value: filteredAndSorted.map(\.id))
                    }
                }
            }
            .navigationTitle("Crypto Tracker")
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await vm.load() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(vm.isLoading)
                }
            }
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
                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: change)
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.gray.opacity(0.12), lineWidth: 1)
        )
    }
}

private struct CoinRichRowView: View {
    let coin: Crypto
    let logoURL: URL?

    var body: some View {
        let price = coin.usd?.price
        let change1h = coin.usd?.percent_change_1h
        let change24h = coin.usd?.percent_change_24h
        let marketCap = coin.usd?.market_cap
        let volume24h = coin.usd?.volume_24h

        HStack(alignment: .center, spacing: 12) {
            AsyncLogo(url: logoURL)
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(coin.name)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if let rank = coin.cmc_rank {
                        Text("#\(rank)")
                            .font(.caption).bold()
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.gray.opacity(0.15), in: Capsule())
                            .foregroundStyle(.secondary)
                    }
                }
                Text(coin.symbol)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .layoutPriority(0)

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Text(formatPrice(price))
                    .font(.headline)
                    .minimumScaleFactor(0.9)

                HStack(spacing: 10) {
                    if let c1h = change1h {
                        ChangePill(title: "1h", value: c1h)
                            .fixedSize()
                    }
                    if let c24h = change24h {
                        ChangePill(title: "24h", value: c24h)
                            .fixedSize()
                    }
                }

                HStack(spacing: 8) {
                    if let mc = marketCap {
                        Label(shortenCurrency(mc), systemImage: "building.columns")
                            .labelStyle(.iconOnly)
                            .foregroundStyle(.secondary)
                            .overlay(
                                Text(shortenCurrency(mc))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 16),
                                alignment: .leading
                            )
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    if let vol = volume24h {
                        Label(shortenCurrency(vol), systemImage: "chart.bar")
                            .labelStyle(.iconOnly)
                            .foregroundStyle(.secondary)
                            .overlay(
                                Text(shortenCurrency(vol))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 16),
                                alignment: .leading
                            )
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }
            }
            .layoutPriority(1)
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    ContentView()
}
