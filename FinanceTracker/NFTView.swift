import SwiftUI

struct NFTView: View {
    @StateObject private var vm = NFTCollectionsViewModel()
    @State private var searchText = ""
    @State private var showHero = true
    @State private var appearedIDs: Set<String> = []

    private var filtered: [MoralisTopCollection] {
        guard !searchText.isEmpty else { return vm.collections }
        let q = searchText.lowercased()
        return vm.collections.filter { ($0.collection_title ?? "").lowercased().contains(q) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading && vm.collections.isEmpty {
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

// Simplified Hero Header (keeps penguin, removes colorful overlays/snow)
private struct CartoonNFTHeader: View {
    var isLoading: Bool

    @State private var bob: CGFloat = 0
    @State private var blink: Bool = false
    @State private var wave: CGFloat = 0

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.thinMaterial)

                Penguin(blink: blink, wave: wave)
                    .frame(width: 110, height: 110)
                    .offset(y: bob)
                    .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 6)
                    .animation(.interpolatingSpring(stiffness: 140, damping: 10), value: bob)
            }
            .frame(maxWidth: .infinity)

            if isLoading {
                Text("Fetching awesome NFT collections…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.accentColor)
            } else {
                Text("Explore top and hottest collections")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.gray.opacity(0.12), lineWidth: 1)
        )
        .onAppear { startAnimations() }
        .onChange(of: isLoading) { _, loading in
            if loading { startAnimations() }
        }
    }

    private func startAnimations() {
        withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) {
            bob = -8
        }
        Timer.scheduledTimer(withTimeInterval: 2.4, repeats: true) { _ in
            withAnimation(.linear(duration: 0.12)) { blink = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                withAnimation(.linear(duration: 0.12)) { blink = false }
            }
        }
        let interval = 3.0
        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.35)) { wave = 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation(.easeOut(duration: 0.35)) { wave = 0 }
            }
        }
    }
}

private struct Penguin: View {
    var blink: Bool
    var wave: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(LinearGradient(colors: [Color.black.opacity(0.95), Color.black.opacity(0.8)], startPoint: .top, endPoint: .bottom))
                .frame(width: 90, height: 100)
                .overlay(
                    Ellipse()
                        .fill(Color.white)
                        .frame(width: 70, height: 76)
                        .offset(y: 8)
                )

            HStack(spacing: 18) {
                PenguinEye(blink: blink)
                PenguinEye(blink: blink)
            }
            .offset(y: -18)

            Triangle()
                .fill(Color.orange)
                .frame(width: 18, height: 14)
                .offset(y: -4)

            Wing()
                .fill(Color.black.opacity(0.95))
                .frame(width: 26, height: 40)
                .rotationEffect(.degrees(Double(-20 + 40 * wave)), anchor: .topTrailing)
                .offset(x: -52, y: 4)

            Wing()
                .fill(Color.black.opacity(0.95))
                .frame(width: 26, height: 40)
                .rotationEffect(.degrees(12), anchor: .topLeading)
                .offset(x: 52, y: 6)

            HStack(spacing: 20) {
                Capsule().fill(Color.orange).frame(width: 18, height: 8)
                Capsule().fill(Color.orange).frame(width: 18, height: 8)
            }
            .offset(y: 44)
        }
        .accessibilityLabel("Penguin mascot waving hello")
        .animation(.easeInOut(duration: 0.25), value: wave)
        .animation(.easeInOut(duration: 0.12), value: blink)
    }
}

private struct PenguinEye: View {
    var blink: Bool
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.white)
                .frame(width: 16, height: blink ? 2 : 12)
                .overlay(
                    Circle()
                        .fill(Color.black)
                        .frame(width: blink ? 0 : 6, height: blink ? 0 : 6)
                        .offset(y: blink ? 0 : 1)
                        .opacity(blink ? 0 : 1)
                )
        }
        .frame(width: 16, height: 12)
    }
}

private struct Wing: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        p.move(to: CGPoint(x: w, y: 0))
        p.addQuadCurve(to: CGPoint(x: 0, y: h * 0.45), control: CGPoint(x: w * 0.1, y: h * 0.1))
        p.addQuadCurve(to: CGPoint(x: w * 0.9, y: h), control: CGPoint(x: w * 0.5, y: h * 0.95))
        p.addLine(to: CGPoint(x: w, y: 0))
        return p
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// Minimal placeholder (kept but neutral). You can also replace with static rectangles if preferred.
private struct ShimmerRow: View {
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8).fill(.gray.opacity(0.15))
                .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 6).fill(.gray.opacity(0.15))
                    .frame(height: 14)
                RoundedRectangle(cornerRadius: 6).fill(.gray.opacity(0.15))
                    .frame(width: 140, height: 10)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 8) {
                RoundedRectangle(cornerRadius: 6).fill(.gray.opacity(0.15))
                    .frame(width: 60, height: 12)
                RoundedRectangle(cornerRadius: 6).fill(.gray.opacity(0.15))
                    .frame(width: 40, height: 10)
            }
        }
        .redacted(reason: .placeholder)
    }
}

#Preview {
    NFTView()
}
