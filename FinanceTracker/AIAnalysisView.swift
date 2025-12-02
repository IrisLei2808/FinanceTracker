import SwiftUI
import Combine

struct AIAnalysisView: View {
    let cryptos: [Crypto]

    @Environment(\.dismiss) private var dismiss
    @State private var messages: [AIMessage] = []
    @State private var isAnalyzing = false

    // Compute top movers (by absolute 24h change) once for the ticker
    private var topMovers: [Crypto] {
        cryptos
            .sorted { abs($0.usd?.percent_change_24h ?? 0) > abs($1.usd?.percent_change_24h ?? 0) }
            .prefix(12)
            .map { $0 }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Animated horizontal slider (marquee) on top
                if !topMovers.isEmpty {
                    AnimatedTicker(items: topMovers) { coin in
                        TickerChip(coin: coin)
                    }
                    .frame(height: 48) // slightly taller and explicit
                    .frame(maxWidth: .infinity, alignment: .leading) // ensure it gets width
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(.thinMaterial)
                    .overlay(
                        // subtle edge fade to emphasize motion
                        HStack {
                            LinearGradient(
                                colors: [Color(.systemBackground).opacity(0.8), Color.clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(width: 16)
                            Spacer()
                            LinearGradient(
                                colors: [Color.clear, Color(.systemBackground).opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(width: 16)
                        }
                    )
                }

                // Messages list
                MessagesList(messages: messages)
            }
            .navigationTitle("AI Market Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await analyzeToday() }
                    } label: {
                        if isAnalyzing {
                            ProgressView()
                        } else {
                            Image(systemName: "sparkles")
                        }
                    }
                    .disabled(isAnalyzing)
                    .help("Analyze market today")
                }
            }
            .onAppear {
                if messages.isEmpty {
                    Task { await initialSummary() }
                }
            }
        }
    }

    // MARK: - Analysis

    @MainActor
    private func appendAssistant(_ text: String) {
        messages.append(.assistant(text))
        // Keep last 50 to avoid heavy UI as history grows
        if messages.count > 50 {
            messages.removeFirst(messages.count - 50)
        }
    }

    private func computeSummary() async -> String {
        // Do work off the main actor to avoid blocking UI
        await withTaskGroup(of: String.self, returning: String.self) { group in
            group.addTask {
                // Detached heavy work
                await Task.detached(priority: .userInitiated) {
                    MarketAnalyzer.summary(from: cryptos)
                }.value
            }
            return await group.next() ?? "No market data available yet. Pull to refresh."
        }
    }

    private func analyzeToday() async {
        await MainActor.run { isAnalyzing = true }
        let summary = await computeSummary()
        await MainActor.run {
            appendAssistant("Market analysis for today:\n\n" + summary)
            isAnalyzing = false
        }
    }

    private func initialSummary() async {
        await MainActor.run { isAnalyzing = true }
        let summary = await computeSummary()
        await MainActor.run {
            appendAssistant(summary)
            isAnalyzing = false
        }
    }
}

private struct MessagesList: View {
    let messages: [AIMessage]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(messages) { msg in
                    MessageRow(message: msg)
                }
            }
            .padding(.vertical, 12)
        }
    }
}

private struct MessageRow: View {
    let message: AIMessage

    var body: some View {
        HStack(alignment: .top) {
            roleIcon
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 6) {
                Text(message.text)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .padding(10)
                    .background(bubbleBackground, in: RoundedRectangle(cornerRadius: 10))
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal)
    }

    private var roleIcon: some View {
        Group {
            if message.role == .assistant {
                Image(systemName: "sparkles")
                    .foregroundStyle(Color.accentColor)
            } else {
                Image(systemName: "person.crop.circle")
                    .foregroundStyle(Color.secondary)
            }
        }
    }

    private var bubbleBackground: Color {
        message.role == .assistant ? Color.accentColor.opacity(0.08) : Color.gray.opacity(0.12)
    }
}

private enum MarketAnalyzer {
    static func summary(from list: [Crypto]) -> String {
        guard !list.isEmpty else { return "No market data available yet. Pull to refresh." }

        // Breadth
        let advancers = list.filter { ($0.usd?.percent_change_24h ?? 0) > 0 }.count
        let decliners = list.filter { ($0.usd?.percent_change_24h ?? 0) < 0 }.count
        let unchanged = list.count - advancers - decliners
        let breadth = String(format: "Breadth: %d advancers, %d decliners, %d unchanged.", advancers, decliners, unchanged)

        // Average and median 24h change
        let changes = list.compactMap { $0.usd?.percent_change_24h }.sorted()
        let avg = changes.reduce(0, +) / Double(max(1, changes.count))
        let median = changes.isEmpty ? 0 : (changes[changes.count/2] + changes[(changes.count-1)/2]) / 2
        let avgStr = String(format: "Avg 24h change: %.2f%%", avg)
        let medStr = String(format: "Median 24h change: %.2f%%", median)

        // Top gainers/losers
        let topGainers = list.sorted { ($0.usd?.percent_change_24h ?? -Double.infinity) > ($1.usd?.percent_change_24h ?? -Double.infinity) }.prefix(5)
        let topLosers = list.sorted { ($0.usd?.percent_change_24h ?? Double.infinity) < ($1.usd?.percent_change_24h ?? Double.infinity) }.prefix(5)

        func line(_ c: Crypto) -> String {
            let p = c.usd?.price ?? 0
            let ch = c.usd?.percent_change_24h ?? 0
            return "\(c.symbol): \(formatPrice(p)) (\(String(format: "%.2f", ch))%)"
        }

        let gainersStr = topGainers.map(line).joined(separator: "\n")
        let losersStr = topLosers.map(line).joined(separator: "\n")

        // Largest market caps
        let largest = list.sorted { ($0.usd?.market_cap ?? 0) > ($1.usd?.market_cap ?? 0) }.prefix(5)
        let largestStr = largest.map { c in
            let mc = c.usd?.market_cap ?? 0
            return "\(c.symbol): \(shortenCurrency(mc))"
        }.joined(separator: "\n")

        // Compose
        return """
        Here’s a quick read on the market:

        \(breadth)
        \(avgStr) • \(medStr)

        Top gainers (24h):
        \(gainersStr)

        Top losers (24h):
        \(losersStr)

        Largest market caps:
        \(largestStr)
        """
    }

    static func reply(to prompt: String, with list: [Crypto]) -> String {
        let q = prompt.lowercased()

        if q.contains("gainer") || q.contains("up") {
            let top = list.sorted { ($0.usd?.percent_change_24h ?? -Double.infinity) > ($1.usd?.percent_change_24h ?? -Double.infinity) }.prefix(10)
            if top.isEmpty { return "No gainers found in the current snapshot." }
            return "Top gainers (24h):\n" + top.map {
                "\($0.symbol): \(formatPrice($0.usd?.price)) (\(String(format: "%.2f", $0.usd?.percent_change_24h ?? 0))%)"
            }.joined(separator: "\n")
        }

        if q.contains("loser") || q.contains("down") {
            let bottom = list.sorted { ($0.usd?.percent_change_24h ?? Double.infinity) < ($1.usd?.percent_change_24h ?? Double.infinity) }.prefix(10)
            if bottom.isEmpty { return "No losers found in the current snapshot." }
            return "Top losers (24h):\n" + bottom.map {
                "\($0.symbol): \(formatPrice($0.usd?.price)) (\(String(format: "%.2f", $0.usd?.percent_change_24h ?? 0))%)"
            }.joined(separator: "\n")
        }

        if q.contains("market cap") || q.contains("dominance") {
            let largest = list.sorted { ($0.usd?.market_cap ?? 0) > ($1.usd?.market_cap ?? 0) }.prefix(10)
            if largest.isEmpty { return "No market cap data available." }
            return "Largest market caps:\n" + largest.map {
                "\($0.symbol): \(shortenCurrency($0.usd?.market_cap ?? 0))"
            }.joined(separator: "\n")
        }

        if q.contains("overview") || q.contains("summary") || q.contains("market") {
            return summary(from: list)
        }

        return "I can summarize the market, show top gainers/losers, and largest market caps based on the latest data. Try: “overview”, “top gainers”, “top losers”, or “largest market caps”."
    }
}

private struct AIMessage: Identifiable {
    enum Role { case user, assistant }
    let id = UUID()
    let role: Role
    let text: String

    static func user(_ text: String) -> AIMessage { .init(role: .user, text: text) }
    static func assistant(_ text: String) -> AIMessage { .init(role: .assistant, text: text) }
}

// MARK: - Animated Ticker Components

private struct AnimatedTicker<Item, Content>: View where Item: Identifiable, Content: View {
    let items: [Item]
    let content: (Item) -> Content

    @State private var rowWidth: CGFloat = 0
    @State private var offset: CGFloat = 0
    @State private var isRunning: Bool = false

    // Points per second
    private let speed: CGFloat = 120

    var body: some View {
        // Give the ticker horizontal space to measure
        GeometryReader { proxy in
            let availableWidth = proxy.size.width
            ZStack {
                // 3x rows for guaranteed overflow and seamless loop
                HStack(spacing: 16) {
                    TickerRow(items: items, content: content)
                        .background(WidthReader(totalWidth: $rowWidth))
                    TickerRow(items: items, content: content)
                    TickerRow(items: items, content: content)
                }
                .offset(x: offset)
                .onAppear {
                    // Start after the first layout pass
                    DispatchQueue.main.async {
                        startIfPossible(availableWidth: availableWidth)
                    }
                }
                .onChange(of: items.map(\.id)) { _, _ in
                    isRunning = false
                    offset = 0
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        startIfPossible(availableWidth: availableWidth)
                    }
                }
                .onChange(of: rowWidth) { _, _ in
                    startIfPossible(availableWidth: availableWidth)
                }

                // If width is zero, show a shimmer so you know it's alive
                if rowWidth <= 1 {
                    LinearGradient(colors: [.gray.opacity(0.15), .gray.opacity(0.05), .gray.opacity(0.15)],
                                   startPoint: .leading, endPoint: .trailing)
                        .animation(.linear(duration: 1.2).repeatForever(autoreverses: false), value: UUID())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipped()
        }
    }

    private func startIfPossible(availableWidth: CGFloat) {
        guard rowWidth > 1, !isRunning else { return }
        isRunning = true
        print("Ticker measured rowWidth =", rowWidth, "availableWidth =", availableWidth)
        // Move one row to the left per cycle
        let duration = rowWidth / speed
        animate(duration: duration)
    }

    private func animate(duration: CGFloat) {
        withAnimation(.linear(duration: duration)) {
            offset = -rowWidth
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            offset = 0
            if isRunning, rowWidth > 1 {
                animate(duration: rowWidth / speed)
            }
        }
    }
}

private struct TickerRow<Item, Content>: View where Item: Identifiable, Content: View {
    let items: [Item]
    let content: (Item) -> Content

    var body: some View {
        HStack(spacing: 16) {
            ForEach(items) { item in
                content(item)
            }
        }
    }
}

private struct WidthReader: View {
    @Binding var totalWidth: CGFloat

    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .preference(key: WidthKey.self, value: proxy.size.width)
        }
        .onPreferenceChange(WidthKey.self) { w in
            if w > 0 {
                totalWidth = w
                print("WidthReader measured =", w)
            }
        }
    }
}

private struct WidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct TickerChip: View {
    let coin: Crypto

    var body: some View {
        let change = coin.usd?.percent_change_24h ?? 0
        HStack(spacing: 8) {
            Text(coin.symbol)
                .font(.caption).bold()
            Text(formatChange(change))
                .font(.caption2).bold()
                .foregroundStyle(change >= 0 ? .green : .red)
            Text(formatPrice(coin.usd?.price))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.gray.opacity(0.12), in: Capsule())
    }
}
