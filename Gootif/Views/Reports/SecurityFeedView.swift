import SwiftUI

/// Agent 3 — trending LLM security news, rendered as a news feed.
struct SecurityFeedView: View {
    let notification: GootifNotification
    var onDelete: (() -> Void)?

    private var report: SecurityReport? { notification.payload(SecurityReport.self) }

    // UI-testing hook: start scrolled to a given anchor for screenshots.
    private var testScrollAnchor: UnitPoint? {
        if let i = CommandLine.arguments.firstIndex(of: "-scrollY"),
           i + 1 < CommandLine.arguments.count,
           let y = Double(CommandLine.arguments[i + 1]) {
            return UnitPoint(x: 0.5, y: y)
        }
        return nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ReportMasthead(
                    kicker: "LLM Security",
                    title: notification.title,
                    dateLine: notification.createdDate?.formatted(date: .complete, time: .shortened)
                )

                if let summary = report?.summary, !summary.isEmpty {
                    MarkdownText(text: summary)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let blocks = report?.blocks, !blocks.isEmpty {
                    BlocksView(blocks: blocks)
                }

                if let items = report?.items, !items.isEmpty {
                    ForEach(items) { item in
                        SecurityItemCard(item: item)
                    }
                } else if report == nil {
                    Text(notification.body).foregroundStyle(.secondary)
                }

                ReportFooter(notification: notification, onDelete: onDelete)
            }
            .padding()
        }
        .defaultScrollAnchor(testScrollAnchor)
    }
}

private struct SecurityItemCard: View {
    let item: SecurityItem

    private var venueColor: Color {
        switch item.venue?.lowercased() {
        case "academia": return AppColors.accentSecondary
        case "industry": return AppColors.info
        default: return AppColors.subtleText
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if let category = item.category {
                    TagChip(text: category, color: AppColors.accent)
                }
                if let venue = item.venue {
                    TagChip(text: venue.capitalized, color: venueColor)
                }
                Spacer()
                ImportanceTag(importance: item.importance)
            }

            Text(item.headline)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)

            SourceLine(source: item.source, timestamp: item.publishedAt)

            if let insight = item.insight, !insight.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Key insight", systemImage: "lightbulb.max.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.accent)
                    MarkdownText(text: insight)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            }

            if let blocks = item.blocks, !blocks.isEmpty {
                BlocksView(blocks: blocks)
            }

            if let innovation = item.innovation, !innovation.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.caption)
                        .foregroundStyle(AppColors.accentSecondary)
                    (Text("What's new: ").bold() + Text(innovation))
                        .font(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let summary = item.summary, !summary.isEmpty, summary != item.insight {
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let tags = item.tags, !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(tags, id: \.self) { TagChip(text: $0, color: AppColors.subtleText) }
                    }
                }
            }

            ReadAtSourceLink(urlString: item.url)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .floatingCard()
    }
}
