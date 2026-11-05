import SwiftUI

/// One page of the reader: a rich report renderer when the notification carries
/// a report payload, otherwise the plain alert. Navigation and delete live in
/// the pager's toolbar.
struct NotificationDetailView: View {
    let notification: GootifNotification

    var body: some View {
        switch notification.kind {
        case .newsFeed:
            NewsReportView(notification: notification)
        case .taskDigest:
            TaskDigestView(notification: notification)
        case .securityFeed:
            SecurityFeedView(notification: notification)
        case nil:
            genericContent
        }
    }

    private var details: [(key: String, value: JSONValue)] {
        notification.metadata
            .filter { !$0.value.isContainer }
            .sorted { $0.key < $1.key }
    }

    private var genericContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    ServiceBadge(serviceName: notification.service, size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(notification.service)
                            .font(.subheadline.weight(.semibold))
                        HStack(spacing: 8) {
                            PriorityPill(priority: notification.priority)
                            if let date = notification.createdDate {
                                Text(date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                SelectableText(text: notification.title, style: .title2, bold: true)

                if let url = notification.primaryURL {
                    OpenLinkButton(url: url)
                }

                if !notification.body.isEmpty {
                    SelectableText(text: notification.body)
                }

                if !details.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(details, id: \.key) { key, value in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(key)
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(.secondary)
                                SelectableText(text: value.displayString, style: .subheadline)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .cardSurface()
                }
            }
            .readableContent()
        }
    }
}

struct PriorityPill: View {
    let priority: String

    var body: some View {
        let color = Importance.color(priority) ?? .secondary
        Text(priority.capitalized)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}
