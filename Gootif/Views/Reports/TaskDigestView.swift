import SwiftUI

/// Agent 2 — inbox + calendar digest, rendered as grouped checklist sections.
struct TaskDigestView: View {
    let notification: GootifNotification
    var onDelete: (() -> Void)?

    private var digest: TaskDigest? { notification.payload(TaskDigest.self) }

    /// Groups items by `category`, preserving first-seen order.
    private var sections: [(category: String, items: [TaskItem])] {
        guard let items = digest?.items else { return [] }
        var order: [String] = []
        var buckets: [String: [TaskItem]] = [:]
        for item in items {
            let key = item.category ?? "Other"
            if buckets[key] == nil { order.append(key); buckets[key] = [] }
            buckets[key]?.append(item)
        }
        return order.map { ($0, buckets[$0] ?? []) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ReportMasthead(
                    kicker: "Inbox & Calendar",
                    title: notification.title,
                    dateLine: notification.createdDate?.formatted(date: .complete, time: .shortened)
                )

                if let summary = digest?.summary, !summary.isEmpty {
                    MarkdownText(text: summary)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let blocks = digest?.blocks, !blocks.isEmpty {
                    BlocksView(blocks: blocks)
                }

                if sections.isEmpty && digest == nil {
                    Text(notification.body).foregroundStyle(.secondary)
                }

                ForEach(sections, id: \.category) { section in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(section.category)
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(spacing: 0) {
                            ForEach(Array(section.items.enumerated()), id: \.element.id) { index, item in
                                TaskItemRow(item: item)
                                    .padding(.vertical, 10)
                                if index < section.items.count - 1 {
                                    Divider().opacity(0.4)
                                }
                            }
                        }
                        .floatingCard()
                    }
                }

                ReportFooter(notification: notification, onDelete: onDelete)
            }
            .padding()
        }
    }
}

private struct TaskItemRow: View {
    let item: TaskItem

    private var typeSymbol: String {
        switch item.type?.lowercased() {
        case "email": return "envelope.fill"
        case "event": return "calendar"
        case "task": return "checklist"
        default: return "circle.fill"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: typeSymbol)
                .font(.callout)
                .foregroundStyle(AppColors.accent)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top, spacing: 6) {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ImportanceTag(importance: item.importance)
                }

                if let detail = item.detail, !detail.isEmpty {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 8) {
                    if let source = item.source {
                        TagChip(text: source, color: AppColors.accentSecondary)
                    }
                    if let due = ReportDate.short(item.due) {
                        Label(due, systemImage: "clock")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(AppColors.warning)
                    }
                }

                ReadAtSourceLink(urlString: item.url)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
