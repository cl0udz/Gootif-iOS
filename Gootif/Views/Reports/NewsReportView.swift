import SwiftUI

/// Agent 1 — pre-market financial brief, rendered Apple-News style.
struct NewsReportView: View {
    let notification: GootifNotification
    var onDelete: (() -> Void)?

    private var report: NewsReport? { notification.payload(NewsReport.self) }

    // UI-testing hook: start scrolled to a given anchor for screenshots.
    private var testScrollAnchor: UnitPoint? {
        if CommandLine.arguments.contains("-scrollBottom") { return .bottom }
        if CommandLine.arguments.contains("-scrollCenter") { return .center }
        if let i = CommandLine.arguments.firstIndex(of: "-scrollY"),
           i + 1 < CommandLine.arguments.count,
           let y = Double(CommandLine.arguments[i + 1]) {
            return UnitPoint(x: 0.5, y: y)
        }
        return nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ReportMasthead(
                    kicker: report?.edition ?? "Pre-Market Brief",
                    title: notification.title,
                    dateLine: notification.createdDate?.formatted(date: .complete, time: .shortened)
                )

                if let summary = report?.summary, !summary.isEmpty {
                    MarkdownText(text: summary)
                        .font(.title3)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let blocks = report?.blocks, !blocks.isEmpty {
                    BlocksView(blocks: blocks)
                }

                if let items = report?.items, !items.isEmpty {
                    Divider()
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        NewsStoryCard(item: item)
                        if index < items.count - 1 {
                            Divider().padding(.vertical, 4)
                        }
                    }
                } else if report == nil {
                    // Payload missing/unparseable — show the plain body as a fallback.
                    Text(notification.body)
                        .foregroundStyle(.secondary)
                }

                ReportFooter(notification: notification, onDelete: onDelete)
            }
            .padding()
        }
        .defaultScrollAnchor(testScrollAnchor)
    }
}

private struct NewsStoryCard: View {
    let item: NewsItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                SentimentChip(sentiment: item.sentiment)
                ImportanceTag(importance: item.importance)
                Spacer()
            }

            Text(item.headline)
                .font(.system(.title3, design: .serif).weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)

            SourceLine(source: item.source, timestamp: item.publishedAt)

            if let tickers = item.tickers, !tickers.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(tickers, id: \.self) { TickerChip(ticker: $0) }
                    }
                }
            }

            if let summary = item.summary, !summary.isEmpty {
                Text(summary)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let blocks = item.blocks, !blocks.isEmpty {
                BlocksView(blocks: blocks)
            }

            if let impact = item.impact, !impact.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Impact on SPY / QQQ", systemImage: "chart.line.uptrend.xyaxis")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.accent)
                    Text(impact)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            }

            ReadAtSourceLink(urlString: item.url)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
