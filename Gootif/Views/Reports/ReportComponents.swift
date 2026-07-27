import SwiftUI

// MARK: - Markdown paragraph

/// Renders inline markdown (bold, italics, links) while preserving whitespace.
struct MarkdownText: View {
    let text: String
    var body: some View {
        if let attr = try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            Text(attr)
        } else {
            Text(text)
        }
    }
}

// MARK: - Masthead (Apple-News-style header)

struct ReportMasthead: View {
    let kicker: String
    let title: String
    let dateLine: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(kicker.uppercased())
                .font(.caption.weight(.bold))
                .tracking(1.5)
                .foregroundStyle(AppColors.accent)

            Text(title)
                .font(.system(.largeTitle, design: .serif).weight(.bold))
                .fixedSize(horizontal: false, vertical: true)

            if let dateLine {
                Text(dateLine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Importance tag

struct ImportanceTag: View {
    let importance: String?

    private var config: (label: String, color: Color)? {
        switch importance?.lowercased() {
        case "high": return ("High", AppColors.negative)
        case "medium": return ("Medium", AppColors.warning)
        case "low": return ("Low", AppColors.subtleText)
        default: return nil
        }
    }

    var body: some View {
        if let config {
            Text(config.label)
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(config.color.opacity(0.18), in: Capsule())
                .foregroundStyle(config.color)
        }
    }
}

// MARK: - Sentiment chip (financial)

struct SentimentChip: View {
    let sentiment: String?

    private var config: (label: String, symbol: String, color: Color)? {
        switch sentiment?.lowercased() {
        case "bullish": return ("Bullish", "arrow.up.right", AppColors.positive)
        case "bearish": return ("Bearish", "arrow.down.right", AppColors.negative)
        case "neutral": return ("Neutral", "arrow.right", AppColors.subtleText)
        default: return nil
        }
    }

    var body: some View {
        if let config {
            HStack(spacing: 3) {
                Image(systemName: config.symbol)
                Text(config.label)
            }
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(config.color.opacity(0.18), in: Capsule())
            .foregroundStyle(config.color)
        }
    }
}

// MARK: - Small pills / chips

struct TickerChip: View {
    let ticker: String
    var body: some View {
        Text(ticker.uppercased())
            .font(.caption2.weight(.bold).monospaced())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(AppColors.accent.opacity(0.15), in: RoundedRectangle(cornerRadius: 5))
            .foregroundStyle(AppColors.accent)
    }
}

struct TagChip: View {
    let text: String
    var color: Color = AppColors.accentSecondary
    var body: some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}

struct SourceLine: View {
    let source: String?
    let timestamp: String?

    var body: some View {
        let rel = ReportDate.relative(timestamp)
        if source != nil || rel != nil {
            HStack(spacing: 6) {
                if let source {
                    Text(source).fontWeight(.medium)
                }
                if source != nil && rel != nil {
                    Text("•")
                }
                if let rel {
                    Text(rel)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

// MARK: - "Read at source" link

struct ReadAtSourceLink: View {
    let urlString: String?

    var body: some View {
        if let urlString, let url = URL(string: urlString) {
            Link(destination: url) {
                HStack(spacing: 4) {
                    Text("Read at source")
                    Image(systemName: "arrow.up.right")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.accent)
            }
        }
    }
}

// MARK: - Shared footer (timestamp + delete)

struct ReportFooter: View {
    let notification: GootifNotification
    var onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var isDeleting = false

    var body: some View {
        VStack(spacing: 16) {
            if let date = notification.createdDate {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                    Text("Generated \(date.formatted(date: .abbreviated, time: .shortened))")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button(role: .destructive) {
                Task { await delete() }
            } label: {
                HStack {
                    if isDeleting {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "trash")
                    }
                    Text("Delete Report")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppColors.negative, in: Capsule())
            }
            .disabled(isDeleting)
        }
        .padding(.top, 8)
    }

    private func delete() async {
        isDeleting = true
        do {
            try await APIClient.deleteNotification(id: notification.id)
            onDelete?()
            dismiss()
        } catch {
            isDeleting = false
        }
    }
}
