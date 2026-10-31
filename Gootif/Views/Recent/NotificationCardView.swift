import SwiftUI

struct NotificationCardView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let notification: GootifNotification

    var body: some View {
        HStack(spacing: 14) {
            ServiceBadge(serviceName: notification.service)

            VStack(alignment: .leading, spacing: 4) {
                Text(notification.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)

                (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4)) : AnyLayout(HStackLayout(spacing: 6))) {
                    Text(notification.service)
                        .font(.caption)
                        .foregroundStyle(AppColors.accent)

                    Text(notification.relativeTime)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            PriorityIndicator(priority: notification.priority)
        }
        .floatingCard()
    }
}
