import SwiftUI
import UIKit

// MARK: - Color(hex:)

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255.0
            g = Double((int >> 8) & 0xFF) / 255.0
            b = Double(int & 0xFF) / 255.0
        default:
            r = 0; g = 0; b = 0
        }
        self.init(red: r, green: g, blue: b)
    }

    /// A color that resolves differently in light and dark mode.
    init(light: String, dark: String) {
        self.init(uiColor: UIColor { traits in
            UIColor(Color(hex: traits.userInterfaceStyle == .dark ? dark : light))
        })
    }
}

// MARK: - Semantic Colors
//
// One accent, and status colors from the system palette so text and tints
// stay readable on solid surfaces in both modes. Everything else is label
// hierarchy (.primary / .secondary) on opaque backgrounds — never on material,
// where vibrancy washes secondary text out.

enum AppColors {
    static let accent = Color(light: "0369A1", dark: "38BDF8")
    static let accentSecondary = Color(uiColor: .systemIndigo)
    static let positive = Color(uiColor: .systemGreen)
    static let warning = Color(uiColor: .systemOrange)
    static let negative = Color(uiColor: .systemRed)
    static let info = Color(uiColor: .systemBlue)
    static let cardBackground = Color(uiColor: .secondarySystemGroupedBackground)
    static let insetBackground = Color(uiColor: .tertiarySystemFill)
    static let subtleText = Color.secondary
}

// MARK: - App background

struct AppBackground: View {
    var body: some View {
        Color(uiColor: .systemGroupedBackground)
            .ignoresSafeArea()
    }
}

// MARK: - Card surface

extension View {
    /// An opaque grouped-content card. No shadow or material: hierarchy comes
    /// from the background step, so nested content keeps full contrast.
    func cardSurface(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Service badge

struct ServiceBadge: View {
    let serviceName: String
    var size: CGFloat = 44

    private var config: (symbol: String, color: Color) {
        ServiceBadge.serviceIcons[serviceName.lowercased()] ?? ("bell.fill", AppColors.accent)
    }

    static let serviceIcons: [String: (symbol: String, color: Color)] = [
        "home-server": ("server.rack", Color(uiColor: .systemIndigo)),
        "nas": ("externaldrive.fill", Color(uiColor: .systemPurple)),
        "pi": ("cpu", Color(uiColor: .systemPink)),
        "docker": ("shippingbox.fill", Color(uiColor: .systemBlue)),
        "backup": ("arrow.clockwise.icloud.fill", Color(uiColor: .systemGreen)),
        "monitor": ("waveform.path.ecg", Color(uiColor: .systemOrange)),
        "security": ("lock.shield.fill", Color(uiColor: .systemRed)),
        "cron": ("clock.fill", Color(uiColor: .systemIndigo)),
        "test-service": ("testtube.2", Color(uiColor: .systemTeal)),
        "iphone duo": ("iphone", Color(uiColor: .systemGray)),
        // Claude agents
        "premarket-brief": ("chart.line.uptrend.xyaxis", Color(uiColor: .systemGreen)),
        "robin-agent": ("chart.line.uptrend.xyaxis", Color(uiColor: .systemGreen)),
        "inbox-digest": ("tray.full.fill", Color(uiColor: .systemIndigo)),
        "llm-security": ("brain.head.profile", Color(uiColor: .systemPurple)),
    ]

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(config.color.gradient)
            Image(systemName: config.symbol)
                .font(.system(size: size * 0.46, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - Priority / importance

enum Importance {
    static func color(_ level: String?) -> Color? {
        switch level?.lowercased() {
        case "high": return AppColors.negative
        case "medium": return AppColors.warning
        default: return nil
        }
    }
}

struct PriorityIndicator: View {
    let priority: String

    var body: some View {
        Circle()
            .fill(Importance.color(priority) ?? Color(uiColor: .systemGray3))
            .frame(width: 8, height: 8)
    }
}

// MARK: - Layout helpers

// Constrain the reading measure while letting the scroll surface fill its pane.
extension View {
    func readableContent(maxWidth: CGFloat = 760) -> some View {
        self
            .frame(maxWidth: maxWidth, alignment: .leading)
            .padding(.horizontal)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .top)
    }
}

/// Lays children out left to right, wrapping onto new lines — for chips and
/// tags, which should never be cut off behind a horizontal scroll.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    var lineSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + lineSpacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private struct Row { var indices: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = rows[rows.count - 1].indices.isEmpty ? size.width : rows[rows.count - 1].width + spacing + size.width
            if needed > width, !rows[rows.count - 1].indices.isEmpty {
                rows.append(Row())
            }
            var row = rows[rows.count - 1]
            row.width = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            row.height = max(row.height, size.height)
            row.indices.append(index)
            rows[rows.count - 1] = row
        }
        return rows.filter { !$0.indices.isEmpty }
    }
}
