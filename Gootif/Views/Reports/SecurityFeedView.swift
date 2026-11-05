import SwiftUI

/// Agent 3 — trending LLM security news. Built for skimming: the summary and a
/// numbered index come first, and each item shows only its headline and
/// takeaway until expanded, grouped by importance.
struct SecurityFeedView: View {
    let notification: GootifNotification

    @State private var expanded: Set<String> = []
    @State private var summaryExpanded = false

    private var report: SecurityReport? { notification.payload(SecurityReport.self) }

    /// Items ordered high → low importance, keeping the agent's order within a level.
    private var items: [SecurityItem] {
        (report?.items ?? []).enumerated()
            .sorted { (Self.rank($0.element.importance), $0.offset) < (Self.rank($1.element.importance), $1.offset) }
            .map(\.element)
    }

    private var groups: [(title: String, items: [(number: Int, item: SecurityItem)])] {
        var result: [(title: String, items: [(number: Int, item: SecurityItem)])] = []
        for (offset, item) in items.enumerated() {
            let title = Self.groupTitle(item.importance)
            if result.last?.title != title { result.append((title, [])) }
            result[result.count - 1].items.append((offset + 1, item))
        }
        return result
    }

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
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ReportMasthead(
                        kicker: "LLM Security",
                        title: notification.title,
                        dateLine: notification.createdDate?.formatted(date: .complete, time: .shortened)
                    )

                    if let summary = report?.summary, !summary.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Summary", systemImage: "text.alignleft")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppColors.accent)
                            MarkdownText(text: summary)
                                .font(.body)
                                .lineSpacing(3)
                                .lineLimit(summaryExpanded ? nil : 5)
                                .fixedSize(horizontal: false, vertical: true)
                            // Keep the index within reach: long summaries start folded.
                            if summary.count > 160 {
                                Button(summaryExpanded ? "Show Less" : "Show More") {
                                    withAnimation(.snappy) { summaryExpanded.toggle() }
                                }
                                .font(.subheadline.weight(.semibold))
                                .accessibilityIdentifier("report-summary-toggle")
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cardSurface()
                    }

                    if let blocks = report?.blocks, !blocks.isEmpty {
                        BlocksView(blocks: blocks)
                    }

                    if !items.isEmpty {
                        ReportIndex(items: items, allExpanded: expanded.count == items.count) { item in
                            withAnimation(.snappy) {
                                expanded.insert(item.id)
                                proxy.scrollTo(item.id, anchor: .top)
                            }
                        } toggleAll: {
                            withAnimation(.snappy) {
                                expanded = expanded.count == items.count ? [] : Set(items.map(\.id))
                            }
                        }

                        ForEach(groups, id: \.title) { group in
                            Text(group.title)
                                .font(.title3.weight(.bold))
                                .padding(.top, 8)

                            ForEach(group.items, id: \.item.id) { entry in
                                SecurityItemCard(
                                    item: entry.item,
                                    number: entry.number,
                                    isExpanded: Binding(
                                        get: { expanded.contains(entry.item.id) },
                                        set: { open in
                                            if open { expanded.insert(entry.item.id) } else { expanded.remove(entry.item.id) }
                                        }
                                    )
                                )
                                .id(entry.item.id)
                            }
                        }
                    } else if report == nil {
                        Text(notification.body)
                    }

                    ReportFooter(notification: notification)
                }
                .readableContent()
                .textSelection(.enabled)
            }
            .defaultScrollAnchor(testScrollAnchor)
        }
    }

    private static func rank(_ importance: String?) -> Int {
        switch importance?.lowercased() {
        case "high": return 0
        case "medium": return 1
        case "low": return 2
        default: return 3
        }
    }

    private static func groupTitle(_ importance: String?) -> String {
        switch importance?.lowercased() {
        case "high": return String(localized: "High importance")
        case "medium": return String(localized: "Medium importance")
        case "low": return String(localized: "Low importance")
        default: return String(localized: "Other")
        }
    }
}

// MARK: - Index

/// One line per item, so the whole report can be scanned before reading any of it.
private struct ReportIndex: View {
    let items: [SecurityItem]
    let allExpanded: Bool
    let jump: (SecurityItem) -> Void
    let toggleAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label("In this report · \(items.count)", systemImage: "list.number")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.accent)
                Spacer()
                Button(allExpanded ? "Collapse All" : "Expand All", action: toggleAll)
                    .font(.subheadline.weight(.medium))
                    .accessibilityIdentifier("report-toggle-all")
            }
            .padding(.bottom, 4)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 16, alignment: .top)],
                      alignment: .leading, spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { offset, item in
                    Button { jump(item) } label: {
                        IndexRow(number: offset + 1, item: item)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("report-index-\(offset + 1)")
                }
            }
        }
        .cardSurface()
    }
}

private struct IndexRow: View {
    let number: Int
    let item: SecurityItem

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(number)")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(Importance.color(item.importance) ?? .secondary)
                .frame(minWidth: 18, alignment: .trailing)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.headline)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if let meta = [item.category, item.source].compactMap({ $0 }).joined(separator: " · ").nilIfEmpty {
                    Text(meta)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "arrow.down.forward")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

// MARK: - Item

private struct SecurityItemCard: View {
    let item: SecurityItem
    let number: Int
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            FlowLayout(spacing: 6) {
                Text("#\(number)")
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .padding(.vertical, 3)
                    .foregroundStyle(.secondary)
                ImportanceTag(importance: item.importance)
                if let category = item.category {
                    TagChip(text: category, color: AppColors.accent)
                }
                if let venue = item.venue {
                    TagChip(text: venue.capitalized)
                }
            }

            Text(item.headline)
                .font(.title3.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)

            SourceLine(source: item.source, timestamp: item.publishedAt)

            if let insight = item.insight, !insight.isEmpty {
                MarkdownText(text: insight)
                    .font(.body)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 12)
                    .overlay(alignment: .leading) {
                        Capsule().fill(AppColors.accent).frame(width: 3)
                    }
            }

            if isExpanded {
                details
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            HStack {
                Button {
                    withAnimation(.snappy) { isExpanded.toggle() }
                } label: {
                    Label(isExpanded ? "Show Less" : "Details", systemImage: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.subheadline.weight(.semibold))
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppColors.accent)
                .accessibilityIdentifier("report-item-\(number)-toggle")

                Spacer()

                ReadAtSourceLink(urlString: item.url)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    @ViewBuilder
    private var details: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let innovation = item.innovation, !innovation.isEmpty {
                section("What's New", systemImage: "sparkles") {
                    Text(innovation)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let summary = item.summary, !summary.isEmpty, summary != item.insight {
                section("Details", systemImage: "doc.text") {
                    MarkdownText(text: summary)
                        .font(.body)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let blocks = item.blocks, !blocks.isEmpty {
                BlocksView(blocks: blocks)
            }

            if let tags = item.tags, !tags.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(tags, id: \.self) { TagChip(text: $0) }
                }
            }

            if let evidence = item.evidence, !evidence.isEmpty {
                section("Sources", systemImage: "link") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(evidence, id: \.self) { source in
                            if let url = URL(string: source.url) {
                                Link(destination: url) {
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(url.host() ?? source.url)
                                            .font(.subheadline.weight(.medium))
                                        if let locator = source.locator {
                                            Text(locator)
                                                .font(.footnote)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(2)
                                                .multilineTextAlignment(.leading)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(.top, 4)
    }

    private func section<Content: View>(_ title: LocalizedStringKey, systemImage: String,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
