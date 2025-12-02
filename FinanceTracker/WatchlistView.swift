import SwiftUI

struct WatchlistView: View {
    @State private var items: [String] = [] // Replace with your real model

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "star")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("Watchlist")
                            .font(.title2).bold()
                        Text("Your saved coins and stocks will appear here.")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                        Button {
                            // Example add action for demo
                            items.append("BTC")
                        } label: {
                            Label("Add Example", systemImage: "plus")
                        }
                    }
                    .padding()
                } else {
                    List {
                        ForEach(items, id: \.self) { item in
                            Text(item)
                        }
                        .onDelete { idx in
                            items.remove(atOffsets: idx)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Watchlist")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        items.append("AAPL")
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
}

#Preview {
    WatchlistView()
}
