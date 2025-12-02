import SwiftUI

enum PriceRange: String, CaseIterable, Identifiable {
    case h1 = "1H", d1 = "1D", w1 = "1W", m1 = "1M", y1 = "1Y"
    var id: String { rawValue }
}

struct CoinDetailView: View {
    let coin: Crypto
    let logoURL: URL?

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
                // favorite toggle placeholder
            } label: {
                Image(systemName: "star")
                    .imageScale(.large)
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
            }
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

// MARK: - Small components

private struct SegmentedTabs: View {
    let tabs: [String]
    @Binding var selection: Int
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(tabs.enumerated()), id: \.offset) { idx, title in
                    Button {
                        selection = idx
                    } label: {
                        Text(title)
                            .font(.subheadline).bold()
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(selection == idx ? Color.accentColor : Color.clear, in: Capsule())
                            .overlay(Capsule().stroke(Color.secondary.opacity(0.25), lineWidth: 1))
                            .foregroundStyle(selection == idx ? Color.white : Color.primary)
                    }
                }
            }
        }
    }
}

// Enhanced Line Chart with smoothing, grid, markers, and scrub interaction
private struct EnhancedLineChart: View {
    let points: [Double]
    let accent: Color

    @State private var dragX: CGFloat? = nil

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            let minY = points.min() ?? 0
            let maxY = points.max() ?? 1
            let pad = max(0.0001, (maxY - minY) * 0.08)
            let lo = minY - pad
            let hi = maxY + pad
            let span = max(hi - lo, 0.000001)

            // Mapping closures (values, not nested function declarations)
            let x: (Int) -> CGFloat = { i in
                guard points.count > 1 else { return 0 }
                return CGFloat(Double(i) / Double(points.count - 1)) * w
            }
            let y: (Double) -> CGFloat = { v in
                h - CGFloat((v - lo) / span) * h
            }

            ZStack {
                // Background grid
                let gridLines = 4
                ForEach(0...gridLines, id: \.self) { idx in
                    let yy = CGFloat(idx) / CGFloat(gridLines) * h
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: yy))
                        p.addLine(to: CGPoint(x: w, y: yy))
                    }
                    .stroke(Color.secondary.opacity(0.15), style: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                }

                // Smooth path (Catmull–Rom spline to Bezier)
                let path = smoothPath(points: points, x: x, y: y)
                path
                    .stroke(accent, style: StrokeStyle(lineWidth: 2, lineJoin: .round))
                    .shadow(color: accent.opacity(0.25), radius: 3, x: 0, y: 1)

                // Area fill
                pathFill(path: path, w: w, h: h)
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(0.25), accent.opacity(0.05), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                // Min/Max markers
                if let (minIdx, minVal) = indexedExtreme(points, by: <) {
                    marker(x: x(minIdx), y: y(minVal), color: .secondary.opacity(0.8))
                }
                if let (maxIdx, maxVal) = indexedExtreme(points, by: >) {
                    marker(x: x(maxIdx), y: y(maxVal), color: .secondary.opacity(0.8))
                }

                // Last point marker and label
                if let last = points.last {
                    let lx = x(points.count - 1)
                    let ly = y(last)
                    marker(x: lx, y: ly, color: accent)
                    // Value label
                    Text(formatPrice(last))
                        .font(.caption2).bold()
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().stroke(Color.black.opacity(0.05), lineWidth: 0.5))
                        .position(x: min(max(40, lx), w - 40), y: max(12, ly - 16))
                }

                // Scrub interaction
                if let dx = dragX {
                    let idx = max(0, min(points.count - 1, Int(round(Double(dx / max(w, 1)) * Double(points.count - 1)))))
                    let vx = x(idx)
                    let vy = y(points[idx])

                    // Vertical guide
                    Path { p in
                        p.move(to: CGPoint(x: vx, y: 0))
                        p.addLine(to: CGPoint(x: vx, y: h))
                    }
                    .stroke(Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))

                    // Bubble
                    Text(formatPrice(points[idx]))
                        .font(.caption2).bold()
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(.thinMaterial, in: Capsule())
                        .overlay(Capsule().stroke(Color.black.opacity(0.05), lineWidth: 0.5))
                        .position(x: min(max(40, vx), w - 40), y: max(12, vy - 16))

                    marker(x: vx, y: vy, color: accent)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        dragX = min(max(0, value.location.x), w)
                    }
                    .onEnded { _ in
                        withAnimation(.easeOut(duration: 0.2)) { dragX = nil }
                    }
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: Helpers

    private func marker(x: CGFloat, y: CGFloat, color: Color) -> some View {
        ZStack {
            Circle().fill(Color.white).frame(width: 8, height: 8)
            Circle().fill(color).frame(width: 6, height: 6)
        }
        .position(x: x, y: y)
        .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
    }

    private func pathFill(path: Path, w: CGFloat, h: CGFloat) -> Path {
        var area = Path()
        area.addPath(path)
        area.addLine(to: CGPoint(x: w, y: h))
        area.addLine(to: CGPoint(x: 0, y: h))
        area.closeSubpath()
        return area
    }

    private func indexedExtreme(_ arr: [Double], by cmp: (Double, Double) -> Bool) -> (Int, Double)? {
        guard var best = arr.first else { return nil }
        var bestIdx = 0
        for (i, v) in arr.enumerated() where cmp(v, best) {
            best = v
            bestIdx = i
        }
        return (bestIdx, best)
    }

    // Build a smooth Bezier path from discrete points using Catmull–Rom spline
    private func smoothPath(points: [Double], x: (Int) -> CGFloat, y: (Double) -> CGFloat) -> Path {
        var path = Path()
        guard points.count > 1 else { return path }

        let n = points.count
        func point(_ i: Int) -> CGPoint {
            CGPoint(x: x(i), y: y(points[i]))
        }

        let p0 = point(0)
        path.move(to: p0)

        for i in 0..<n - 1 {
            let p1 = point(i)
            let p2 = point(i + 1)
            let p0 = i == 0 ? p1 : point(i - 1)
            let p3 = i + 2 < n ? point(i + 2) : p2

            // Catmull–Rom to Bezier control points
            let tension: CGFloat = 0.5
            let c1 = CGPoint(
                x: p1.x + (p2.x - p0.x) * tension / 6.0,
                y: p1.y + (p2.y - p0.y) * tension / 6.0
            )
            let c2 = CGPoint(
                x: p2.x - (p3.x - p1.x) * tension / 6.0,
                y: p2.y - (p3.y - p1.y) * tension / 6.0
            )
            path.addCurve(to: p2, control1: c1, control2: c2)
        }
        return path
    }
}

struct AsyncLogo: View {
    let url: URL?

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                ZStack {
                    Circle().fill(.gray.opacity(0.15))
                    ProgressView().scaleEffect(0.7)
                }
            case .success(let img):
                img.resizable().scaledToFit().clipShape(Circle())
            case .failure:
                ZStack {
                    Circle().fill(.gray.opacity(0.15))
                    Image(systemName: "bitcoinsign.circle")
                        .imageScale(.large)
                        .foregroundStyle(.secondary)
                }
            @unknown default:
                EmptyView()
            }
        }
    }
}

struct ChangePill: View {
    let title: String
    let value: Double

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: value >= 0 ? "arrow.up.right" : "arrow.down.right")
            Text(title)
            Text(formatChange(value))
        }
        .font(.caption)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background((value >= 0 ? Color.green.opacity(0.15) : Color.red.opacity(0.15)), in: Capsule())
        .foregroundStyle(value >= 0 ? .green : .red)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: value)
    }
}

struct ChangeBar: View {
    // value in percent points, e.g., -2.5 or 5.3
    let percent: Double

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let clamped = max(-20, min(20, percent)) // clamp -20%..20% for visualization
            let fill = (clamped + 20) / 40 // map to 0..1
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.gray.opacity(0.15))
                RoundedRectangle(cornerRadius: 3)
                    .fill(percent >= 0 ? Color.green : Color.red)
                    .frame(width: width * CGFloat(fill))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}

#Preview {
    ContentView()
}
