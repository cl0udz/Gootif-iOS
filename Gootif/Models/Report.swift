import Foundation

// MARK: - Report kinds
//
// Agents post regular notifications, but enrich `metadata` with:
//   - "kind":    one of ReportKind below — selects the native renderer
//   - "payload": a structured object matching the kind's schema
//
// Unknown / absent kinds fall back to the generic notification detail view.
// See server/agents/REPORTS.md for the full agent → app contract.

enum ReportKind: String {
    case newsFeed = "news_feed"          // agent 1 — pre-market financial brief
    case taskDigest = "task_digest"      // agent 2 — inbox + calendar digest
    case securityFeed = "security_feed"  // agent 3 — LLM security news
}

extension GootifNotification {
    /// The report renderer requested by the agent, if any.
    var kind: ReportKind? {
        guard case .string(let raw)? = metadata["kind"] else { return nil }
        return ReportKind(rawValue: raw)
    }

    /// Decode the structured `metadata.payload` into a typed model.
    /// Works by re-encoding the JSONValue subtree and decoding `T` from it.
    func payload<T: Decodable>(_ type: T.Type) -> T? {
        guard let value = metadata["payload"] else { return nil }
        guard let data = try? JSONEncoder().encode(value) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}

// MARK: - news_feed (agent 1: pre-market financial brief)

struct NewsReport: Codable {
    let edition: String?
    let summary: String?
    let blocks: [ReportBlock]?
    let items: [NewsItem]
}

struct NewsItem: Codable, Identifiable {
    let headline: String
    let source: String?
    let url: String?
    let publishedAt: String?
    let summary: String?
    let impact: String?
    let sentiment: String?   // bullish | bearish | neutral
    let tickers: [String]?
    let importance: String?  // high | medium | low
    let blocks: [ReportBlock]?

    var id: String { (url ?? "") + headline }

    enum CodingKeys: String, CodingKey {
        case headline, source, url, summary, impact, sentiment, tickers, importance, blocks
        case publishedAt = "published_at"
    }
}

// MARK: - task_digest (agent 2: inbox + calendar)

struct TaskDigest: Codable {
    let summary: String?
    let blocks: [ReportBlock]?
    let items: [TaskItem]
}

struct TaskItem: Codable, Identifiable {
    let title: String
    let detail: String?
    let due: String?
    let source: String?      // e.g. "gmail: work", "calendar"
    let url: String?
    let importance: String?  // high | medium | low
    let category: String?    // e.g. "Needs reply", "Upcoming events", "Deadlines", "FYI"
    let type: String?        // email | event | task
    let blocks: [ReportBlock]?

    var id: String { title + (due ?? "") + (source ?? "") }
}

// MARK: - security_feed (agent 3: LLM security news)

struct SecurityReport: Codable {
    let summary: String?
    let blocks: [ReportBlock]?
    let items: [SecurityItem]
}

struct SecurityItem: Codable, Identifiable {
    let headline: String
    let source: String?
    let url: String?
    let publishedAt: String?
    let insight: String?     // 1–2 sentence distilled takeaway (the "so what")
    let innovation: String?  // one line: what's new (method/technique)
    let summary: String?
    let category: String?    // e.g. "LLM for security", "Security of LLM"
    let venue: String?       // academia | industry
    let tags: [String]?
    let importance: String?  // high | medium | low
    let blocks: [ReportBlock]?

    var id: String { (url ?? "") + headline }

    enum CodingKeys: String, CodingKey {
        case headline, source, url, insight, innovation, summary, category, venue, tags, importance, blocks
        case publishedAt = "published_at"
    }
}

// MARK: - Shared formatting for ISO8601 timestamps in payloads

enum ReportDate {
    static func parse(_ iso: String?) -> Date? {
        guard let iso, !iso.isEmpty else { return nil }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        if let date = plain.date(from: iso) { return date }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: iso)
    }

    static func relative(_ iso: String?) -> String? {
        guard let date = parse(iso) else { return nil }
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f.localizedString(for: date, relativeTo: .now)
    }

    /// Short calendar/time label, e.g. "Jul 1, 5:00 PM".
    static func short(_ iso: String?) -> String? {
        guard let date = parse(iso) else { return nil }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}
