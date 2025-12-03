import SwiftUI
import SafariServices
import Combine

// MARK: - Models

private struct NDResponse: Decodable {
    let status: String
    let totalResults: Int?
    let results: [NDArticle]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.status = (try? c.decode(String.self, forKey: .status)) ?? (try? c.decode(String.self, forKey: .statusUpper)) ?? "unknown"
        self.totalResults = try? c.decode(Int.self, forKey: .totalResults)
        // Support both "results" and "data" arrays
        if let r = try? c.decode([NDArticle].self, forKey: .results) {
            self.results = r
        } else if let d = try? c.decode([NDArticle].self, forKey: .data) {
            self.results = d
        } else {
            self.results = []
        }
    }

    private enum CodingKeys: String, CodingKey {
        case status
        case statusUpper = "Status"
        case totalResults
        case results
        case data
    }
}

private struct NDArticle: Decodable, Identifiable {
    // snake_case -> camelCase via .convertFromSnakeCase
    let articleId: String?
    let link: String?
    let title: String?
    let description: String?
    let content: String?
    let keywords: [String]?
    let creator: [String]?
    // coin can be String or [String] in payloads; store normalized array
    let coin: [String]?
    let language: String?
    let pubDate: String?
    let pubDateTz: String?
    let imageUrl: String?
    let videoUrl: String?
    let sourceId: String?
    let sourceName: String?
    let sourcePriority: Int?
    let sourceUrl: String?
    let sourceIcon: String?
    let sentiment: String?
    let sentimentStats: String?
    let aiTag: String?
    let duplicate: Bool?

    // Flexible decoding for coin (String or [String])
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.articleId = try? c.decode(String.self, forKey: .articleId)
        self.link = try? c.decode(String.self, forKey: .link)
        self.title = try? c.decode(String.self, forKey: .title)
        self.description = try? c.decode(String.self, forKey: .description)
        self.content = try? c.decode(String.self, forKey: .content)
        self.keywords = try? c.decode([String].self, forKey: .keywords)
        self.creator = try? c.decode([String].self, forKey: .creator)

        if let arr = try? c.decode([String].self, forKey: .coin) {
            self.coin = arr
        } else if let str = try? c.decode(String.self, forKey: .coin) {
            self.coin = str.isEmpty ? nil : [str]
        } else {
            self.coin = nil
        }

        self.language = try? c.decode(String.self, forKey: .language)
        self.pubDate = try? c.decode(String.self, forKey: .pubDate)
        self.pubDateTz = try? c.decode(String.self, forKey: .pubDateTz)
        self.imageUrl = try? c.decode(String.self, forKey: .imageUrl)
        self.videoUrl = try? c.decode(String.self, forKey: .videoUrl)
        self.sourceId = try? c.decode(String.self, forKey: .sourceId)
        self.sourceName = try? c.decode(String.self, forKey: .sourceName)
        self.sourcePriority = try? c.decode(Int.self, forKey: .sourcePriority)
        self.sourceUrl = try? c.decode(String.self, forKey: .sourceUrl)
        self.sourceIcon = try? c.decode(String.self, forKey: .sourceIcon)
        self.sentiment = try? c.decode(String.self, forKey: .sentiment)
        self.sentimentStats = try? c.decode(String.self, forKey: .sentimentStats)
        self.aiTag = try? c.decode(String.self, forKey: .aiTag)
        self.duplicate = try? c.decode(Bool.self, forKey: .duplicate)
    }

    private enum CodingKeys: String, CodingKey {
        case articleId, link, title, description, content, keywords, creator, coin, language
        case pubDate, pubDateTz, imageUrl, videoUrl
        case sourceId, sourceName, sourcePriority, sourceUrl, sourceIcon
        case sentiment, sentimentStats, aiTag, duplicate
    }

    var id: String {
        if let articleId, !articleId.isEmpty { return articleId }
        if let link, !link.isEmpty { return "link:\(link)" }
        if let title, !title.isEmpty { return "title:\(title)" }
        return UUID().uuidString
    }

    // Helpers
    var url: URL? { link.flatMap { URL(string: $0) } }
    var imageURL: URL? { imageUrl.flatMap { URL(string: $0) } }

    var titleText: String { normalize(title) ?? "Untitled" }
    var descriptionText: String? {
        normalize(description).flatMap { s in s.isEmpty ? nil : s }
    }
    var sourceText: String {
        if let name = sourceName, !name.isEmpty { return name }
        if let id = sourceId, !id.isEmpty { return id }
        if let host = url?.host { return host }
        return "Unknown"
    }
    var publishedDate: Date? {
        guard let raw = pubDate else { return nil }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        let fmts = [
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ssXXX"
        ]
        for fmt in fmts {
            f.dateFormat = fmt
            if let d = f.date(from: raw) { return d }
        }
        return nil
    }
    var coinDisplay: String? {
        guard let coin, !coin.isEmpty else { return nil }
        return coin.joined(separator: ", ")
    }

    // Fix common mojibake artifacts seen in some feeds
    private func normalize(_ s: String?) -> String? {
        guard var s = s?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return s }
        let replacements: [(String, String)] = [
            ("â€“", "–"), ("â€”", "—"),
            ("â€˜", "‘"), ("â€™", "’"),
            ("â€œ", "“"), ("â€\u{9d}", "”"), ("â€", "”"),
            ("â€¦", "…"),
            ("â€¢", "•"),
            ("Â ", " "),
            ("Â", "")
        ]
        for (bad, good) in replacements {
            s = s.replacingOccurrences(of: bad, with: good)
        }
        return s
    }
}

// MARK: - Service

private enum NewsDataError: Error, LocalizedError {
    case invalidURL
    case badStatus(Int)
    case decoding(Error, String?)
    case transport(Error)
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .badStatus(let c): return "Bad HTTP status: \(c)"
        case .decoding(let e, let snippet):
            if let snippet, !snippet.isEmpty {
                return "Failed to decode: \(e.localizedDescription)\nSnippet: \(snippet)"
            }
            return "Failed to decode: \(e.localizedDescription)"
        case .transport(let e): return "Network error: \(e.localizedDescription)"
        case .apiError(let m): return m
        }
    }
}

private struct NewsDataService {
    enum Feed: String {
        case crypto, market
        var path: String { rawValue }
    }

    let apiKey: String

    func fetch(_ feed: Feed) async throws -> [NDArticle] {
        guard let url = URL(string: "https://newsdata.io/api/1/\(feed.path)?apikey=\(apiKey)") else {
            throw NewsDataError.invalidURL
        }
        #if DEBUG
        print("Fetching NewsData feed=\(feed.rawValue) url=\(url.absoluteString)")
        #endif
        do {
            let (data, resp) = try await URLSession.shared.data(from: url)
            guard let http = resp as? HTTPURLResponse else { throw NewsDataError.badStatus(-1) }
            guard 200..<300 ~= http.statusCode else { throw NewsDataError.badStatus(http.statusCode) }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase

            do {
                let decoded = try decoder.decode(NDResponse.self, from: data)
                #if DEBUG
                print("NewsData \(feed.rawValue) status=\(decoded.status) total=\(decoded.totalResults ?? -1) results=\(decoded.results.count)")
                #endif
                if decoded.status.lowercased() != "success" {
                    if let msg = Self.extractAPIServerMessage(from: data) {
                        throw NewsDataError.apiError(msg)
                    }
                }
                return decoded.results.filter { ($0.link?.isEmpty == false) || ($0.title?.isEmpty == false) }
            } catch {
                let raw = String(data: data, encoding: .utf8)
                #if DEBUG
                if let raw { print("NewsData raw (\(feed.rawValue)):", raw) }
                #endif
                throw NewsDataError.decoding(error, raw.map { String($0.prefix(2048)) })
            }
        } catch let e as NewsDataError {
            throw e
        } catch {
            throw NewsDataError.transport(error)
        }
    }

    private static func extractAPIServerMessage(from data: Data) -> String? {
        struct Msg1: Decodable { let message: String?; let status: String? }
        if let m1 = try? JSONDecoder().decode(Msg1.self, from: data), let msg = m1.message, !msg.isEmpty {
            return msg
        }
        return nil
    }
}

// MARK: - ViewModel

@MainActor
private final class NewsDataViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var articles: [NDArticle] = []

    private let service = NewsDataService(apiKey: "pub_16372d7c7a6c4f879d938b53ef3630fb")

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        articles = [] // clear while loading to make change visible
        defer { isLoading = false }

        // Fetch both feeds concurrently
        async let cryptoTask = service.fetch(.crypto)
        async let marketTask = service.fetch(.market)

        var crypto: [NDArticle] = []
        var market: [NDArticle] = []

        // We want to keep partial results even if one fails
        var partialErrors: [String] = []

        do {
            crypto = try await cryptoTask
        } catch {
            partialErrors.append("Crypto feed: " + ((error as? LocalizedError)?.errorDescription ?? error.localizedDescription))
        }
        do {
            market = try await marketTask
        } catch {
            partialErrors.append("Market feed: " + ((error as? LocalizedError)?.errorDescription ?? error.localizedDescription))
        }

        let merged = mergeDiverse(crypto + market, preferredLanguage: "english", maxConsecutivePerSource: 1)
        self.articles = merged

        if !partialErrors.isEmpty, merged.isEmpty {
            self.errorMessage = partialErrors.joined(separator: "\n")
        } else if !partialErrors.isEmpty {
            // Surface as non-blocking info; keep list visible
            self.errorMessage = partialErrors.joined(separator: "\n")
        } else {
            self.errorMessage = nil
        }
    }

    // MARK: Diversity & De-duplication

    private func mergeDiverse(_ list: [NDArticle], preferredLanguage: String, maxConsecutivePerSource: Int) -> [NDArticle] {
        // 1) Group by normalized key (prefer normalized link; fallback to title signature)
        var buckets: [String: [NDArticle]] = [:]
        for a in list {
            let key = normalizedKey(for: a)
            buckets[key, default: []].append(a)
        }

        // 2) Resolve each bucket to best representative (language -> image -> longer description)
        var reps: [NDArticle] = []
        reps.reserveCapacity(buckets.count)
        for (_, items) in buckets {
            if let best = items.reduce(nil as NDArticle?, { acc, cur in
                guard let acc else { return cur }
                return better(of: cur, than: acc, preferredLanguage: preferredLanguage)
            }) {
                reps.append(best)
            } else if let first = items.first {
                reps.append(first)
            }
        }

        // 3) Sort by published date desc
        reps.sort { (lhs, rhs) in
            let ld = lhs.publishedDate ?? .distantPast
            let rd = rhs.publishedDate ?? .distantPast
            return ld > rd
        }

        // 4) Spread sources to avoid consecutive items from same source
        let spread = spreadBySource(reps, maxConsecutive: maxConsecutivePerSource)
        return spread
    }

    private func normalizedKey(for a: NDArticle) -> String {
        if let link = a.link, !link.isEmpty {
            return "url:" + normalizeURLString(link)
        }
        let sig = titleSignature(a.title)
        if !sig.isEmpty { return "title:" + sig }
        if let id = a.articleId, !id.isEmpty { return "id:" + id }
        return "uuid:" + a.id
    }

    private func normalizeURLString(_ s: String) -> String {
        guard var comps = URLComponents(string: s) else { return s }
        comps.scheme = comps.scheme?.lowercased()
        comps.host = comps.host?.lowercased()
        // Remove common tracking params
        let drop: Set<String> = ["utm_source","utm_medium","utm_campaign","utm_term","utm_content","gclid","fbclid","mc_cid","mc_eid"]
        if let q = comps.queryItems {
            comps.queryItems = q.filter { !drop.contains($0.name.lowercased()) && !($0.value ?? "").isEmpty }
            if comps.queryItems?.isEmpty == true { comps.queryItems = nil }
        }
        // Normalize trailing slash
        var path = comps.percentEncodedPath
        if path.count > 1 && path.hasSuffix("/") { path.removeLast() }
        comps.percentEncodedPath = path
        return comps.string ?? s
    }

    private func titleSignature(_ title: String?) -> String {
        guard var t = title?.lowercased(), !t.isEmpty else { return "" }
        t = t.folding(options: .diacriticInsensitive, locale: .current)
        // Remove punctuation and symbols, keep letters/numbers/spaces
        t = t.unicodeScalars
            .map { scalar in
                if CharacterSet.alphanumerics.contains(scalar) {
                    return String(scalar)
                } else if CharacterSet.whitespaces.contains(scalar) {
                    return " "
                } else {
                    return ""
                }
            }
            .joined()
        // Collapse whitespace
        t = t.split(separator: " ").joined(separator: " ")
        // Keep first 12 tokens to avoid overly long signatures
        let tokens = t.split(separator: " ").prefix(12)
        return tokens.joined(separator: " ")
    }

    private func better(of a: NDArticle, than b: NDArticle, preferredLanguage: String) -> NDArticle {
        // 1) Preferred language
        let la = (a.language ?? "").lowercased()
        let lb = (b.language ?? "").lowercased()
        let prefersLangA = la.contains(preferredLanguage.lowercased())
        let prefersLangB = lb.contains(preferredLanguage.lowercased())
        if prefersLangA != prefersLangB { return prefersLangA ? a : b }

        // 2) Has image
        let hasImgA = (a.imageUrl?.isEmpty == false)
        let hasImgB = (b.imageUrl?.isEmpty == false)
        if hasImgA != hasImgB { return hasImgA ? a : b }

        // 3) Longer description
        let lenA = (a.descriptionText ?? "").count
        let lenB = (b.descriptionText ?? "").count
        if lenA != lenB { return lenA > lenB ? a : b }

        // 4) Newer
        let da = a.publishedDate ?? .distantPast
        let db = b.publishedDate ?? .distantPast
        if da != db { return da > db ? a : b }

        // 5) Fallback: keep 'a'
        return a
    }

    private func spreadBySource(_ items: [NDArticle], maxConsecutive: Int) -> [NDArticle] {
        guard maxConsecutive > 0 else { return items }
        var out: [NDArticle] = []
        out.reserveCapacity(items.count)

        var buffer: [NDArticle] = items
        var idx = 0
        var lastSource: String = ""
        var runCount = 0

        func src(_ a: NDArticle) -> String {
            if let s = a.sourceName, !s.isEmpty { return s }
            if let s = a.sourceId, !s.isEmpty { return s }
            if let h = a.url?.host, !h.isEmpty { return h }
            return "unknown"
        }

        while !buffer.isEmpty {
            if idx >= buffer.count { idx = 0 } // wrap
            let candidate = buffer[idx]
            let s = src(candidate)
            if s == lastSource && runCount >= maxConsecutive {
                // Find next item with a different source
                if let j = buffer.firstIndex(where: { src($0) != lastSource }) {
                    let pick = buffer.remove(at: j)
                    out.append(pick)
                    lastSource = src(pick)
                    runCount = 1
                    idx = 0
                } else {
                    // All remaining are same source; allow it
                    let pick = buffer.remove(at: 0)
                    out.append(pick)
                    lastSource = src(pick)
                    runCount += 1
                    idx = 0
                }
            } else {
                let pick = buffer.remove(at: idx)
                out.append(pick)
                if s == lastSource {
                    runCount += 1
                } else {
                    lastSource = s
                    runCount = 1
                }
                // Do not advance idx since we removed at idx
            }
        }
        return out
    }
}

// MARK: - Identified URL wrapper

private struct IdentifiedURL: Identifiable, Equatable {
    let id = UUID()
    let url: URL
}

// MARK: - View

struct NewsHubView: View {
    @StateObject private var vm = NewsDataViewModel()
    @State private var selectedURL: IdentifiedURL?
    @State private var shareURL: IdentifiedURL?

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading && vm.articles.isEmpty {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Fetching latest news…")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let msg = vm.errorMessage, vm.articles.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text("Couldn’t load news")
                            .font(.headline)
                        Text(msg)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                        Button {
                            Task { await vm.load() }
                        } label: {
                            Label("Retry", systemImage: "arrow.clockwise")
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(vm.articles) { article in
                            NewsRow(article: article,
                                    open: {
                                        if let u = article.url { selectedURL = IdentifiedURL(url: u) }
                                    },
                                    share: {
                                        if let u = article.url { shareURL = IdentifiedURL(url: u) }
                                    })
                            .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                        }
                    }
                    .listStyle(.plain)
                    .refreshable { await vm.load() }
                }
            }
            .navigationTitle("News")
        }
        .task { await vm.load() }
        .sheet(item: $selectedURL) { identified in
            SafariView(url: identified.url)
        }
        .sheet(item: $shareURL) { identified in
            ShareSheet(activityItems: [identified.url])
        }
    }
}

// MARK: - Row

private struct NewsRow: View {
    let article: NDArticle
    let open: () -> Void
    let share: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(alignment: .top, spacing: 12) {
                if let img = article.imageURL {
                    AsyncImage(url: img) { phase in
                        switch phase {
                        case .empty:
                            ZStack {
                                RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.12))
                                ProgressView().scaleEffect(0.7)
                            }
                        case .success(let image):
                            image.resizable().scaledToFill()
                        case .failure:
                            ZStack {
                                RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.12))
                                Image(systemName: "photo").foregroundStyle(.secondary)
                            }
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(width: 120, height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(article.sourceText)
                            .font(.caption).bold()
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.15), in: Capsule())
                        if let d = article.publishedDate {
                            Text(relativeTime(from: d))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let coins = article.coinDisplay {
                            Text(coins)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.gray.opacity(0.12), in: Capsule())
                        }
                    }

                    Text(article.titleText)
                        .font(.headline)
                        .lineLimit(3)

                    if let desc = article.descriptionText {
                        Text(desc)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }

                    if let kws = article.keywords, !kws.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(kws.prefix(5), id: \.self) { kw in
                                    Text(kw)
                                        .font(.caption2)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.gray.opacity(0.12), in: Capsule())
                                }
                            }
                        }
                        .padding(.top, 2)
                    }
                }

                Spacer(minLength: 0)

                Button(action: share) {
                    Image(systemName: "square.and.arrow.up")
                        .imageScale(.medium)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func relativeTime(from date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Utility wrappers

private struct SafariView: UIViewControllerRepresentable, Identifiable {
    let id = UUID()
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }
    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}

private struct ShareSheet: UIViewControllerRepresentable, Identifiable {
    let id = UUID()
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

#Preview {
    NewsHubView()
}
