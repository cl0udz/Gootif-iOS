import SwiftUI
import UIKit

// MARK: - Link detection

enum LinkDetector {
    // NSRegularExpression (and so NSDataDetector) is documented as thread-safe.
    nonisolated(unsafe) private static let detector = try? NSDataDetector(
        types: NSTextCheckingResult.CheckingType.link.rawValue
    )

    /// Finds http(s) links. The system detector treats Chinese text directly
    /// after a URL as part of its path, so each match is cut at the first CJK character.
    static func links(in text: String) -> [(range: Range<String.Index>, url: URL)] {
        guard let detector else { return [] }
        let matches = detector.matches(in: text, range: NSRange(text.startIndex..., in: text))
        return matches.compactMap { match in
            guard let matched = Range(match.range, in: text) else { return nil }
            let end = text[matched].firstIndex(where: isCJK) ?? matched.upperBound
            let range = matched.lowerBound..<end
            let raw = String(text[range])
            let candidate = raw.lowercased().hasPrefix("http") ? raw : "https://" + raw
            guard !raw.isEmpty, !raw.contains("@"), let url = URL(string: candidate),
                  ["http", "https"].contains(url.scheme?.lowercased()) else { return nil }
            return (range, url)
        }
    }

    private static func isCJK(_ character: Character) -> Bool {
        character.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x2E80...0x303F, 0x3040...0x9FFF, 0xF900...0xFAFF, 0xFF00...0xFFEF: return true
            default: return false
            }
        }
    }
}

extension GootifNotification {
    /// The link to act on from a plain alert: an explicit metadata URL if there
    /// is one, otherwise the first link in the text. Reports hold many links, so none.
    var primaryURL: URL? {
        guard kind == nil else { return nil }
        let explicit = ["url", "link", "href", "buy_url", "product_url"]
            .compactMap { key -> String? in
                guard case .string(let value)? = metadata[key] else { return nil }
                return value
            }
        let others = metadata.sorted { $0.key < $1.key }.compactMap { _, value -> String? in
            guard case .string(let string) = value else { return nil }
            return string
        }
        for text in explicit + [body, title] + others {
            if let url = LinkDetector.links(in: text).first?.url { return url }
        }
        return nil
    }
}

// MARK: - Selectable text

/// UITextView-backed text. SwiftUI's `.textSelection` on iOS only copies a whole
/// `Text`, so this is what allows selecting part of a message and tapping its links.
struct SelectableText: UIViewRepresentable {
    let text: String
    var style: UIFont.TextStyle = .body
    var bold = false
    var monospaced = false
    var color: UIColor = .label

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.isEditable = false
        view.isSelectable = true
        view.isScrollEnabled = false
        view.backgroundColor = .clear
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        view.adjustsFontForContentSizeCategory = true
        view.linkTextAttributes = [
            .foregroundColor: UIColor(AppColors.accent),
            .underlineStyle: NSUnderlineStyle.single.rawValue,
        ]
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        let content = attributedText
        // Reassigning identical text would clear the user's selection.
        if view.attributedText != content { view.attributedText = content }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        guard let width = proposal.width, width.isFinite else { return nil }
        let fitted = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: fitted.height)
    }

    private var attributedText: NSAttributedString {
        let result = NSMutableAttributedString(
            string: text, attributes: [.font: font, .foregroundColor: color]
        )
        for link in LinkDetector.links(in: text) {
            result.addAttribute(.link, value: link.url, range: NSRange(link.range, in: text))
        }
        return result
    }

    private var font: UIFont {
        // Start from the default size so UIFontMetrics applies Dynamic Type exactly once.
        let traits = UITraitCollection(preferredContentSizeCategory: .large)
        let base = UIFont.preferredFont(forTextStyle: style, compatibleWith: traits)
        let styled: UIFont
        if monospaced {
            styled = .monospacedSystemFont(ofSize: base.pointSize, weight: bold ? .bold : .regular)
        } else if bold, let descriptor = base.fontDescriptor.withSymbolicTraits(.traitBold) {
            styled = UIFont(descriptor: descriptor, size: base.pointSize)
        } else {
            styled = base
        }
        return UIFontMetrics(forTextStyle: style).scaledFont(for: styled)
    }
}

// MARK: - Open link controls

/// Compact one-tap control for a notification row. It must sit beside the row's
/// Button, not inside its label, or the row swallows the tap.
struct RowOpenLinkButton: View {
    let url: URL

    var body: some View {
        Link(destination: url) {
            Image(systemName: "arrow.up.right.circle.fill")
                .font(.title2)
                .foregroundStyle(AppColors.accent)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Open link")
        .accessibilityIdentifier("row-open-link")
    }
}

struct OpenLinkButton: View {
    let url: URL

    var body: some View {
        Link(destination: url) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.up.right")
                Text("Open \(url.host() ?? "Link")")
                    .lineLimit(1)
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.vertical, 6)
            .background(AppColors.accent, in: Capsule())
        }
        .accessibilityIdentifier("detail-open-link")
    }
}
