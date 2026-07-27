import SwiftUI

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
}

// MARK: - Semantic Colors

enum AppColors {
    static let accent = Color(hex: "0EA5E9")
    static let accentSecondary = Color(hex: "6366F1")
    static let positive = Color(hex: "34D399")
    static let warning = Color(hex: "FBBF24")
    static let negative = Color(hex: "F87171")
    static let info = Color(hex: "60A5FA")
    static let cardBackground = Color(uiColor: .systemBackground)
    static let cardBorder = Color.primary.opacity(0.06)
    static let subtleText = Color.secondary
}

// MARK: - App gradient background

struct AppBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if colorScheme == .dark {
                LinearGradient(
                    colors: [
                        Color(hex: "0F172A"),
                        Color(hex: "1E293B"),
                        Color(hex: "0F172A"),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                LinearGradient(
                    colors: [
                        Color(hex: "F0F9FF"),
                        Color(hex: "E0F2FE"),
                        Color(hex: "F0F9FF"),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Floating card

extension View {
    func floatingCard(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(AppColors.cardBorder, lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
    }
}

// MARK: - Service badge

struct ServiceBadge: View {
    let serviceName: String
    var size: CGFloat = 44

    private var config: (symbol: String, color: String) {
        ServiceBadge.serviceIcons[serviceName.lowercased()] ?? ("bell.fill", "0EA5E9")
    }

    static let serviceIcons: [String: (symbol: String, color: String)] = [
        "home-server": ("server.rack", "6366F1"),
        "nas": ("externaldrive.fill", "8B5CF6"),
        "pi": ("cpu", "EC4899"),
        "docker": ("shippingbox.fill", "0EA5E9"),
        "backup": ("arrow.clockwise.icloud.fill", "34D399"),
        "monitor": ("waveform.path.ecg", "F59E0B"),
        "security": ("lock.shield.fill", "EF4444"),
        "cron": ("clock.fill", "6366F1"),
        "test-service": ("testtube.2", "60A5FA"),
        // Claude agents
        "premarket-brief": ("chart.line.uptrend.xyaxis", "34D399"),
        "inbox-digest": ("tray.full.fill", "6366F1"),
        "llm-security": ("brain.head.profile", "8B5CF6"),
    ]

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(Color(hex: config.color))
            Image(systemName: config.symbol)
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Priority indicator

struct PriorityIndicator: View {
    let priority: String

    private var color: Color {
        switch priority {
        case "high": return AppColors.negative
        case "medium": return AppColors.warning
        default: return AppColors.subtleText.opacity(0.5)
        }
    }

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
    }
}
