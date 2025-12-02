import SwiftUI

struct RootTabView: View {
    @StateObject private var portfolio = PortfolioStore()

    init() {
        UITabBar.appearance().unselectedItemTintColor = UIColor.secondaryLabel
    }

    var body: some View {
        TabView {
            // 1) Markets (Crypto)
            ContentView()
                .tabItem {
                    Label("Markets", systemImage: "bitcoinsign.circle")
                }

            // 2) NFT
            NFTView()
                .tabItem {
                    Label("NFT", systemImage: "hexagon")
                }

            // 3) News
            NewsHubView()
                .tabItem {
                    Label("News", systemImage: "newspaper")
                }

            // 4) Portfolio (main tab)
            PortfolioView()
                .environmentObject(portfolio)
                .tabItem {
                    Label("Portfolio", systemImage: "chart.pie.fill")
                }

            // 5) More (contains Watchlist + Settings)
            MoreView()
                .environmentObject(portfolio)
                .tabItem {
                    Label("More", systemImage: "ellipsis.circle")
                }
        }
        .environmentObject(portfolio)
        .tint(Color.accentColor)
    }
}

private struct MoreView: View {
    @EnvironmentObject private var portfolio: PortfolioStore
    @EnvironmentObject private var watchlist: WatchlistStore

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        WatchlistView()
                            .environmentObject(watchlist)
                    } label: {
                        Label("Watchlist", systemImage: "star")
                    }

                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("Settings", systemImage: "gear")
                    }
                }
            }
            .navigationTitle("More")
            .listStyle(.insetGrouped)
        }
    }
}

#Preview {
    RootTabView()
}
