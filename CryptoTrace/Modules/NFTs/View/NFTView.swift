import SwiftUI

struct NFTView: View {
    @StateObject private var vm = NFTCollectionsViewModel()
    @State private var searchText = ""
    @State private var showHero = true
    @State private var appearedIDs: Set<String> = []
    @StateObject private var net = NetworkMonitor.shared

    private var filtered: [MoralisTopCollection] {
        guard !searchText.isEmpty else { return vm.collections }
        let q = searchText.lowercased()
        return vm.collections.filter { ($0.collection_title ?? "").lowercased().contains(q) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if !net.isConnected && vm.collections.isEmpty && !vm.isLoading {
                    OfflineView(
                        title: "You’re Offline",
                        message: "We couldn’t load NFT collections without internet. Reconnect and try again."
                    ) {
                        Task { await vm.forceReload() }
                    }
                } else if vm.isLoading && vm.collections.isEmpty {
                    ScrollView {
                        VStack(spacing: 16) {
                            CartoonNFTHeader(isLoading: vm.isLoading)
                                .padding(.horizontal, 16)
                                .padding(.top, 24)
                            ForEach(0..<6, id: \.self) { _ in
                                ShimmerRow()
                                    .padding(.horizontal, 12)
                            }
                        }
                    }
                    .accessibilityLabel("Loading NFT collections")
                } else if let err = vm.errorMessage, vm.collections.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text("Failed to load NFTs")
                            .font(.headline)
                        Text(err)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                        Button {
                            Task { await vm.forceReload() }
                        } label: {
                            Label("Retry", systemImage: "arrow.clockwise")
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        if showHero {
                            Section {
                                CartoonNFTHeader(isLoading: vm.isLoading)
                                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                                    .listRowBackground(Color.clear)
                                    .onAppear {
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                            withAnimation(.spring(response: 0.6, dampingFraction: 0.9)) {
                                                showHero = false
                                            }
                                        }
                                    }
                            }
                        }

                        Section {
                            Picker("Mode", selection: $vm.mode) {
                                ForEach(NFTCollectionsViewModel.Mode.allCases) { m in
                                    Text(m.rawValue).tag(m)
                                }
                            }
                            .pickerStyle(.segmented)
                            .onChange(of: vm.mode) { _, _ in
                                appearedIDs.removeAll()
                                showHero = true
                                Task { await vm.load() }
                            }
                        }
                        .listRowBackground(Color.clear)

                        ForEach(filtered.indices, id: \.self) { idx in
                            let col = filtered[idx]
                            NavigationLink {
                                CollectionDetailView(collection: col, mode: vm.mode)
                            } label: {
                                NFTCollectionRow(collection: col, mode: vm.mode)
                                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                                    .opacity(appearedIDs.contains(col.id) ? 1 : 0)
                                    .offset(y: appearedIDs.contains(col.id) ? 0 : 12)
                                    .onAppear {
                                        guard !appearedIDs.contains(col.id) else { return }
                                        let delay = Double(appearedIDs.count) * 0.03
                                        withAnimation(.easeOut(duration: 0.35).delay(delay)) {
                                            appearedIDs.insert(col.id)
                                        }
                                    }
                            }
                            .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.plain)
                    .refreshable {
                        appearedIDs.removeAll()
                        showHero = true
                        await vm.forceReload()
                    }
                }
            }
            .navigationTitle("NFT Collections")
            .searchable(text: $searchText)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .task { await vm.load() }
        .onChange(of: vm.isLoading) { _, new in
            if new {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) {
                    showHero = true
                }
            }
        }
    }
}

// Simplified row without colorful gradient backgrounds
private struct NFTCollectionRow: View {
    let collection: MoralisTopCollection
    let mode: NFTCollectionsViewModel.Mode

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            AsyncImage(url: URL(string: collection.collection_image ?? "")) { phase in
                switch phase {
                case .empty:
                    ZStack {
                        RoundedRectangle(cornerRadius: 8).fill(.gray.opacity(0.15))
                        ProgressView().scaleEffect(0.7)
                    }
                case .success(let img):
                    img.resizable().scaledToFill()
                case .failure:
                    ZStack {
                        RoundedRectangle(cornerRadius: 8).fill(.gray.opacity(0.15))
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(collection.collection_title ?? "—")
                        .font(.headline)
                        .lineLimit(1)

                    if let r = collection.rank, mode == .top {
                        Text("#\(r)")
                            .font(.caption).bold()
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.gray.opacity(0.15), in: Capsule())
                            .foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 12) {
                    if let fp = collection.floorPriceUSD {
                        Text("Floor: " + formatPrice(fp))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let change = collection.floorChange24h {
                        HStack(spacing: 4) {
                            Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                            Text(formatChange(change))
                        }
                        .font(.caption).bold()
                        .foregroundStyle(change >= 0 ? .green : .red)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if mode == .hottest {
                    if let vol = collection.volumeUSD {
                        Text("Vol: " + shortenCurrency(vol))
                            .font(.subheadline).bold()
                    }
                    if let vch = collection.volumeChange24h {
                        Text(formatChange(vch))
                            .font(.caption).bold()
                            .foregroundStyle(vch >= 0 ? .green : .red)
                    }
                } else {
                    if let mc = collection.marketCapUSD {
                        Text(shortenCurrency(mc))
                            .font(.subheadline)
                    }
                    if let vol = collection.volumeUSD {
                        Text(shortenCurrency(vol))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .contentShape(Rectangle())
    }
}

// CartoonNFTHeader, Penguin, ShimmerRow remain unchanged from your file above.

#Preview {
    NFTView()
}

