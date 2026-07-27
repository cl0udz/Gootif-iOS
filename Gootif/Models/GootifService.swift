import Foundation

struct GootifService: Codable, Identifiable {
    var id: String { name }
    let name: String
    let notificationCount: Int
    let lastNotificationAt: String?

    enum CodingKeys: String, CodingKey {
        case name
        case notificationCount = "notification_count"
        case lastNotificationAt = "last_notification_at"
    }

    var relativeTime: String? {
        guard let ts = lastNotificationAt else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        guard let date = formatter.date(from: ts) else { return ts }
        let rel = RelativeDateTimeFormatter()
        rel.unitsStyle = .short
        return rel.localizedString(for: date, relativeTo: .now)
    }
}
