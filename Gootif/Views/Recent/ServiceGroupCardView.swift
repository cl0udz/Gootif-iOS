import SwiftUI

struct ServiceGroup: Identifiable {
    let serviceName: String
    let notifications: [GootifNotification]
    var id: String { serviceName }
    var count: Int { notifications.count }
    var latestRelativeTime: String? { notifications.first?.relativeTime }
}

struct ServiceGroupCardView: View {
    let group: ServiceGroup
    var selectedID: String? = nil
    var onSelect: (GootifNotification) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, 12)

            VStack(spacing: 0) {
                ForEach(Array(group.notifications.enumerated()), id: \.element.id) { index, notification in
                    HStack(spacing: 4) {
                        Button {
                            onSelect(notification)
                        } label: {
                            NotificationRow(notification: notification)
                                .padding(.vertical, 10)
                                .notificationSelection(selectedID == notification.id)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("notification-\(notification.id)")

                        if let url = notification.primaryURL {
                            RowOpenLinkButton(url: url)
                        }
                    }

                    if index < group.notifications.count - 1 {
                        Divider().opacity(0.4)
                    }
                }
            }
        }
        .floatingCard()
    }

    private var header: some View {
        HStack(spacing: 12) {
            ServiceBadge(serviceName: group.serviceName, size: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(group.serviceName)
                    .font(.subheadline.weight(.semibold))

                if let time = group.latestRelativeTime {
                    Text("Latest \(time)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text("\(group.count)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.accent)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(AppColors.accent.opacity(0.15), in: Capsule())
        }
    }
}

private struct NotificationRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let notification: GootifNotification

    var body: some View {
        (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(spacing: 12))) {
            PriorityIndicator(priority: notification.priority)

            VStack(alignment: .leading, spacing: 2) {
                Text(notification.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !notification.body.isEmpty {
                    Text(notification.body)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Text(notification.relativeTime)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
}
