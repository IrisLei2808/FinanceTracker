import SwiftUI

struct CollectionDetailView: View {
    let collection: MoralisTopCollection
    let mode: NFTCollectionsViewModel.Mode

    @State private var copied = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                // Stats cards
                statsSection

                // Contract info
                contractSection
            }
            .padding(16)
        }
        .navigationTitle(collection.collection_title ?? "Collection")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let img = collection.collection_image, let url = URL(string: img) {
                    ShareLink(item: url) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            AsyncImage(url: URL(string: collection.collection_image ?? "")) { phase in
                switch phase {
                case .empty:
                    ZStack {
                        RoundedRectangle(cornerRadius: 10).fill(.gray.opacity(0.15))
                        ProgressView().scaleEffect(0.8)
                    }
                case .success(let img):
                    img.resizable().scaledToFill()
                case .failure:
                    ZStack {
                        RoundedRectangle(cornerRadius: 10).fill(.gray.opacity(0.15))
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: 72, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(collection.collection_title ?? "—")
                        .font(.title3).bold()
                        .lineLimit(2)
                    if let r = collection.rank, mode == .top {
                        Text("#\(r)")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.gray.opacity(0.15), in: Capsule())
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 10) {
                    if let fp = collection.floorPriceUSD {
                        Label {
                            Text("Floor " + formatPrice(fp))
                        } icon: {
                            Image(systemName: "diamond")
                        }
                        .font(.subheadline)
                    }
                    if let ch = collection.floorChange24h {
                        HStack(spacing: 4) {
                            Image(systemName: ch >= 0 ? "arrow.up.right" : "arrow.down.right")
                            Text(formatChange(ch))
                        }
                        .font(.caption).bold()
                        .foregroundStyle(ch >= 0 ? .green : .red)
                    }
                }
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
    }

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Statistics").font(.headline)

            VStack(spacing: 8) {
                HStack {
                    Label("Market Cap", systemImage: "building.columns")
                    Spacer()
                    Text(shortenCurrency(collection.marketCapUSD ?? .nan))
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)

                HStack {
                    Label("Volume (24h)", systemImage: "chart.bar")
                    Spacer()
                    Text(shortenCurrency(collection.volumeUSD ?? .nan))
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)

                if let vch = collection.volumeChange24h {
                    HStack {
                        Label("Vol Change (24h)", systemImage: "arrow.left.arrow.right")
                        Spacer()
                        Text(formatChange(vch))
                            .foregroundStyle(vch >= 0 ? .green : .red)
                            .bold()
                    }
                    .font(.subheadline)
                }
            }
            .padding()
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var contractSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Contract").font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Text("Address")
                    Spacer()
                    Text(collection.collection_address ?? "—")
                        .textSelection(.enabled)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                }

                HStack {
                    if let addr = collection.collection_address, !addr.isEmpty {
                        Button {
                            UIPasteboard.general.string = addr
                            copied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copied = false }
                        } label: {
                            Label(copied ? "Copied" : "Copy Address", systemImage: copied ? "checkmark" : "doc.on.doc")
                        }
                    }
                    Spacer()
                    // Placeholder for chain; fixed to Ethereum per your note
                    Label("Chain: Ethereum", systemImage: "bolt.horizontal")
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                }
            }
            .padding()
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}
