import SwiftUI

struct RootTabView: View {
    init() {
        // Global selected tint for tab bar (iOS 15+)
        UITabBar.appearance().unselectedItemTintColor = UIColor.secondaryLabel
    }

    var body: some View {
        TabView {
            // 1) Crypto Tracking (existing main screen)
            ContentView()
                .tabItem {
                    Label("Crypto", systemImage: "bitcoinsign.circle")
                }

            // 2) NFT
            NFTView()
                .tabItem {
                    Label("NFT", systemImage: "hexagon")
                }

            // 3) News (restored)
            NewsHubView()
                .tabItem {
                    Label("News", systemImage: "newspaper")
                }

            // 4) Watchlist
            WatchlistView()
                .tabItem {
                    Label("Watchlist", systemImage: "star")
                }

            // 5) Settings
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .tint(Color.accentColor)
    }
}

#Preview {
    RootTabView()
}
