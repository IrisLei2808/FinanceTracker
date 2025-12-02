import Foundation
import Combine

struct NewsItem: Identifiable {
    let id = UUID()
    let title: String
    let link: String
    let published: Date?
    let source: String
    let imageURL: String?
}

@MainActor
final class NewsViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var items: [NewsItem] = []
    @Published var errorMessage: String?

    // Simple RSS sources
    private let feeds: [(name: String, url: String)] = [
        ("CoinDesk", "https://www.coindesk.com/arc/outboundfeeds/rss/"),
        ("CoinTelegraph", "https://cointelegraph.com/rss")
    ]

    func loadFiltered(for coin: Crypto) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            var all: [NewsItem] = []
            for feed in feeds {
                guard let url = URL(string: feed.url) else { continue }
                let (data, resp) = try await URLSession.shared.data(from: url)
                guard let http = resp as? HTTPURLResponse, 200..<300 ~= http.statusCode else { continue }
                let parsed = RSSParser.parse(data: data, source: feed.name)
                all.append(contentsOf: parsed)
            }

            // Filter by coin name or symbol presence in title (basic heuristic)
            let qName = coin.name.lowercased()
            let qSym = coin.symbol.lowercased()
            let filtered = all.filter { item in
                let t = item.title.lowercased()
                // include hashtag and parens variants
                return t.contains(qName)
                || t.contains(" \(qSym) ")
                || t.hasPrefix(qSym + " ")
                || t.contains("(\(coin.symbol))")
                || t.contains("#\(qSym)")
                || t.contains("$\(qSym)")
            }

            // sort by date desc
            self.items = filtered.sorted { ($0.published ?? .distantPast) > ($1.published ?? .distantPast) }
        } catch {
            self.errorMessage = error.localizedDescription
            self.items = []
        }
    }
}

// Very lightweight RSS parser tailored for simple feeds
enum RSSParser {
    static func parse(data: Data, source: String) -> [NewsItem] {
        // Minimal XML parsing using XMLParser
        final class Delegate: NSObject, XMLParserDelegate {
            let source: String
            init(source: String) {
                self.source = source
            }

            var items: [NewsItem] = []
            var currentTitle: String = ""
            var currentLink: String = ""
            var currentDate: String = ""
            var currentImage: String = ""
            var currentElement: String = ""
            var insideItem = false

            // Track Atom-style link href and media/enclosure attributes
            func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
                currentElement = elementName
                let lower = elementName.lowercased()
                if lower == "item" || lower == "entry" {
                    insideItem = true
                    currentTitle = ""
                    currentLink = ""
                    currentDate = ""
                    currentImage = ""
                } else if insideItem {
                    // Atom link: <link href="...">
                    if lower == "link", let href = attributeDict["href"], !href.isEmpty {
                        currentLink = href
                    }
                    // media:thumbnail or media:content with url
                    if lower == "media:thumbnail" || lower == "media:content" {
                        if let url = attributeDict["url"], !url.isEmpty {
                            currentImage = url
                        }
                    }
                    // RSS enclosure with image
                    if lower == "enclosure" {
                        if let type = attributeDict["type"], type.contains("image"),
                           let url = attributeDict["url"], !url.isEmpty {
                            currentImage = url
                        }
                    }
                }
            }

            func parser(_ parser: XMLParser, foundCharacters string: String) {
                guard insideItem else { return }
                switch currentElement.lowercased() {
                case "title": currentTitle += string
                case "link":
                    // Some RSS put link text (not Atom)
                    if currentLink.isEmpty { currentLink += string }
                case "pubdate", "updated", "published": currentDate += string
                default: break
                }
            }

            func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
                if elementName.lowercased() == "item" || elementName.lowercased() == "entry" {
                    insideItem = false
                    let trimmedDate = currentDate.trimmingCharacters(in: .whitespacesAndNewlines)
                    let date = parseDate(trimmedDate)
                    let title = currentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                    let link = currentLink.trimmingCharacters(in: .whitespacesAndNewlines)
                    let image = currentImage.trimmingCharacters(in: .whitespacesAndNewlines)
                    let item = NewsItem(
                        title: title,
                        link: link,
                        published: date,
                        source: self.source,
                        imageURL: image.isEmpty ? nil : image
                    )
                    items.append(item)
                }
                currentElement = ""
            }

            // Handle multiple common date formats
            private func parseDate(_ s: String) -> Date? {
                let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty { return nil }

                // Try ISO8601 variants
                let iso = ISO8601DateFormatter()
                if let d = iso.date(from: trimmed) { return d }
                let isoOpts: [ISO8601DateFormatter.Options] = [
                    [.withInternetDateTime, .withFractionalSeconds],
                    [.withInternetDateTime],
                    [.withFullDate, .withTime, .withDashSeparatorInDate, .withColonSeparatorInTime, .withTimeZone]
                ]
                for opt in isoOpts {
                    let f = ISO8601DateFormatter()
                    f.formatOptions = opt
                    if let d = f.date(from: trimmed) { return d }
                }

                // Try RFC822/2822 variants
                let fmts = [
                    "E, d MMM yyyy HH:mm:ss Z",
                    "E, dd MMM yyyy HH:mm:ss Z",
                    "E, d MMM yy HH:mm:ss Z",
                    "E, dd MMM yy HH:mm:ss Z",
                    "d MMM yyyy HH:mm:ss Z",
                    "dd MMM yyyy HH:mm:ss Z"
                ]
                let df = DateFormatter()
                df.locale = Locale(identifier: "en_US_POSIX")
                for fmt in fmts {
                    df.dateFormat = fmt
                    if let d = df.date(from: trimmed) { return d }
                }
                return nil
            }
        }

        let parser = XMLParser(data: data)
        let delegate = Delegate(source: source)
        parser.delegate = delegate
        parser.parse()
        return delegate.items
    }
}

enum RFC2822DateFormatter {
    static func date(from string: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "E, d MMM yyyy HH:mm:ss Z"
        return f.date(from: string.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
