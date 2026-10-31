import SwiftUI

struct RecentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var notifications: [GootifNotification] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @Binding var selectedNotification: GootifNotification?

    var body: some View {
        ZStack {
            AppBackground()

            if isLoading && notifications.isEmpty {
                ProgressView("Loading...")
            } else if let error = errorMessage, notifications.isEmpty {
                ContentUnavailableView {
                    Label("Error", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button("Retry") { Task { await load() } }
                }
            } else if notifications.isEmpty {
                ContentUnavailableView {
                    Label("No Notifications", systemImage: "bell.slash")
                } description: {
                    Text("Notifications from your services will appear here.")
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 14) {
                        ForEach(serviceGroups) { group in
                            ServiceGroupCardView(group: group, selectedID: selectedNotification?.id) { notification in
                                selectedNotification = notification
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                }
            }
        }
        .navigationTitle("Recent")
        .refreshable { await load() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Refresh", systemImage: "arrow.clockwise") { Task { await load() } }
                    .disabled(isLoading)
                    .keyboardShortcut("r", modifiers: .command)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await load() } }
        }
        .task(id: PushNotifications.shared.refreshRevision) {
            await load()
            // UI-testing hook: auto-open the newest rich report.
            if CommandLine.arguments.contains("-openLatestReport") {
                selectedNotification = notifications.first { $0.kind != nil }
            }
        }

    }

    private var serviceGroups: [ServiceGroup] {
        var order: [String] = []
        var buckets: [String: [GootifNotification]] = [:]
        for n in notifications {
            if buckets[n.service] == nil {
                order.append(n.service)
                buckets[n.service] = []
            }
            buckets[n.service]?.append(n)
        }
        return order.map { ServiceGroup(serviceName: $0, notifications: buckets[$0] ?? []) }
    }

    private func load() async {
        #if DEBUG
        if CommandLine.arguments.contains("-layoutPreview") {
            notifications = LayoutPreviewData.notifications
            return
        }
        #endif
        isLoading = true
        errorMessage = nil
        do {
            notifications = try await APIClient.fetchNotifications()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

#if DEBUG
/// Offline fixtures for repeatable device, rotation, and Dynamic Type review.
@MainActor
enum LayoutPreviewData {
    static var stories: [JSONValue] {
        (1...18).map { index in
            .object([
                "headline": .string("Reading checkpoint \(index)"),
                "source": .string("Layout review"),
                "summary": .string(String(repeating: "This section checks reading continuity as the window changes width and the device folds. ", count: 5))
            ])
        }
    }
    static let notifications: [GootifNotification] = [
        GootifNotification(
            id: "layout-preview-report", service: "premarket-brief",
            title: "Morning briefing: markets, infrastructure, and the week ahead",
            body: "A sample report for reviewing compact and expanded layouts.", priority: "medium",
            metadata: [
                "kind": .string("news_feed"),
                "payload": .object([
                    "items": .array(CommandLine.arguments.contains("-longReport") ? stories : []),
                    "summary": .string("A readable report should adapt to your window. This sample includes longer text and a four-column table to check both phone and tablet layouts."),
                    "blocks": .array([.object([
                        "type": .string("table"), "title": .string("Market overview"),
                        "columns": .array(["Index", "Last", "Change", "Context"].map { .string($0) }),
                        "rows": .array([
                            .array(["S&P 500", "6,100", "+0.8%", "Technology leads the session"].map { .string($0) }),
                            .array(["Nasdaq", "20,000", "+1.2%", "Broad participation across sectors"].map { .string($0) })
                        ])
                    ])])
                ])
            ], createdAt: "2026-10-21T14:00:00Z"
        ),
        GootifNotification(id: "layout-preview-link", service: "monitor",
                           title: "iPhone Duo in stock", body: "有货：https://www.apple.com/shop/buy-iphone/iphone-duo购买，尽快下单。",
                           priority: "high", metadata: ["store": .string("Apple Online")], createdAt: "2026-10-21T13:45:00Z"),
        GootifNotification(id: "layout-preview-alert", service: "home-server",
                           title: "Backup complete — all services are healthy", body: "The scheduled backup completed successfully.",
                           priority: "low", metadata: [:], createdAt: "2026-10-21T13:30:00Z")
    ]
}
#endif
