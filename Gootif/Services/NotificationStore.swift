import Foundation
import Observation

/// The one notification list the app shows. The inbox and the reading pager
/// share it, so paging follows exactly the rows the filter left visible.
@MainActor
@Observable
final class NotificationStore {
    private(set) var notifications: [GootifNotification] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    /// nil shows every service.
    var serviceFilter: String?

    var visible: [GootifNotification] {
        guard let serviceFilter else { return notifications }
        return notifications.filter { $0.service == serviceFilter }
    }

    /// Services ordered by their newest notification, with counts.
    var services: [(name: String, count: Int)] {
        var order: [String] = []
        var counts: [String: Int] = [:]
        for n in notifications {
            if counts[n.service] == nil { order.append(n.service) }
            counts[n.service, default: 0] += 1
        }
        return order.map { ($0, counts[$0] ?? 0) }
    }

    func load() async {
        #if DEBUG
        if CommandLine.arguments.contains("-layoutPreview") {
            notifications = LayoutPreviewData.notifications
            return
        }
        // Render reports from a local JSON array of notifications (simulator only).
        if let flag = CommandLine.arguments.firstIndex(of: "-reportFixture"), flag + 1 < CommandLine.arguments.count,
           let data = FileManager.default.contents(atPath: CommandLine.arguments[flag + 1]),
           let fixture = try? JSONDecoder().decode([GootifNotification].self, from: data) {
            notifications = fixture
            return
        }
        #endif
        isLoading = true
        errorMessage = nil
        do {
            notifications = try await APIClient.fetchNotifications()
            if let serviceFilter, !notifications.contains(where: { $0.service == serviceFilter }) {
                self.serviceFilter = nil
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    /// Deletes on the server first; the row only disappears once that succeeds.
    func delete(_ notification: GootifNotification) async throws {
        try await APIClient.deleteNotification(id: notification.id)
        notifications.removeAll { $0.id == notification.id }
    }

    /// Makes sure a notification opened from outside the list (a push) can be paged to.
    func reveal(_ notification: GootifNotification) {
        if let filter = serviceFilter, filter != notification.service { serviceFilter = nil }
        guard !notifications.contains(where: { $0.id == notification.id }) else { return }
        notifications.append(notification)
        notifications.sort { ($0.createdDate ?? .distantPast) > ($1.createdDate ?? .distantPast) }
    }

    /// The visible neighbour after removing `notification`, so reading can continue.
    func neighbor(of notification: GootifNotification) -> GootifNotification? {
        let list = visible
        guard let index = list.firstIndex(where: { $0.id == notification.id }) else { return nil }
        if index + 1 < list.count { return list[index + 1] }
        return index > 0 ? list[index - 1] : nil
    }
}
