import SwiftUI

/// Every notification as one timeline, newest first, grouped by day. A chip bar
/// filters to a single service, so a burst from one source never buries the rest.
struct RecentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Bindable var store: NotificationStore
    @Binding var selectedNotification: GootifNotification?
    @State private var deleteError: String?

    var body: some View {
        content
            .navigationTitle("Recent")
            .safeAreaInset(edge: .top, spacing: 0) {
                if store.services.count > 1 { ServiceFilterBar(store: store) }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await store.load() } }
            }
            .task(id: PushNotifications.shared.refreshRevision) {
                await store.load()
                #if DEBUG
                // UI-testing hooks: start filtered, and auto-open the newest rich report.
                let arguments = CommandLine.arguments
                if let flag = arguments.firstIndex(of: "-serviceFilter"), flag + 1 < arguments.count {
                    store.serviceFilter = arguments[flag + 1]
                }
                if arguments.contains("-openLatestReport") {
                    selectedNotification = store.visible.first { $0.kind != nil }
                }
                #endif
            }
            .alert("Could not delete", isPresented: Binding(
                get: { deleteError != nil }, set: { if !$0 { deleteError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: { Text(deleteError ?? "") }
    }

    @ViewBuilder
    private var content: some View {
        if store.isLoading && store.notifications.isEmpty {
            ProgressView("Loading…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = store.errorMessage, store.notifications.isEmpty {
            ContentUnavailableView {
                Label("Couldn't Load", systemImage: "exclamationmark.triangle")
            } description: {
                Text(error)
            } actions: {
                Button("Retry") { Task { await store.load() } }
            }
        } else if store.notifications.isEmpty {
            ContentUnavailableView {
                Label("No Notifications", systemImage: "bell.slash")
            } description: {
                Text("Notifications from your services will appear here.")
            }
        } else {
            List {
                ForEach(daySections, id: \.title) { section in
                    Section(section.title) {
                        ForEach(section.notifications) { notification in
                            row(notification)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .refreshable { await store.load() }
        }
    }

    private func row(_ notification: GootifNotification) -> some View {
        HStack(alignment: .center, spacing: 4) {
            Button {
                selectedNotification = notification
            } label: {
                NotificationRow(notification: notification, showsService: store.serviceFilter == nil)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("notification-\(notification.id)")

            if let url = notification.primaryURL {
                RowOpenLinkButton(url: url)
                    .buttonStyle(.plain)
            }
        }
        .listRowBackground(selectedNotification?.id == notification.id ? AppColors.accent.opacity(0.12) : nil)
        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 12))
        .swipeActions(edge: .trailing) {
            Button("Delete", systemImage: "trash", role: .destructive) { delete(notification) }
        }
        .contextMenu {
            if let url = notification.primaryURL {
                Link(destination: url) { Label("Open Link", systemImage: "arrow.up.right") }
            }
            Button("Delete", systemImage: "trash", role: .destructive) { delete(notification) }
        }
    }

    private func delete(_ notification: GootifNotification) {
        Task {
            do {
                if selectedNotification?.id == notification.id { selectedNotification = nil }
                try await store.delete(notification)
            } catch {
                deleteError = error.localizedDescription
            }
        }
    }

    private var daySections: [(title: String, notifications: [GootifNotification])] {
        let calendar = Calendar.current
        var order: [String] = []
        var buckets: [String: [GootifNotification]] = [:]
        for n in store.visible {
            let title: String
            if let date = n.createdDate {
                if calendar.isDateInToday(date) { title = String(localized: "Today") }
                else if calendar.isDateInYesterday(date) { title = String(localized: "Yesterday") }
                else { title = date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()) }
            } else {
                title = String(localized: "Earlier")
            }
            if buckets[title] == nil { order.append(title) }
            buckets[title, default: []].append(n)
        }
        return order.map { ($0, buckets[$0] ?? []) }
    }
}

// MARK: - Filter bar

private struct ServiceFilterBar: View {
    @Bindable var store: NotificationStore

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("All", count: store.notifications.count, selected: store.serviceFilter == nil, id: "filter-all") {
                    store.serviceFilter = nil
                }
                ForEach(store.services, id: \.name) { service in
                    chip(service.name, count: service.count, selected: store.serviceFilter == service.name,
                         id: "filter-\(service.name)") {
                        store.serviceFilter = store.serviceFilter == service.name ? nil : service.name
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(.bar)
        .sensoryFeedback(.selection, trigger: store.serviceFilter)
    }

    private func chip(_ title: String, count: Int, selected: Bool, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                Text("\(count)")
                    .foregroundStyle(selected ? Color.white.opacity(0.8) : Color.secondary)
                    .monospacedDigit()
            }
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .foregroundStyle(selected ? Color.white : Color.primary)
            .background(selected ? AppColors.accent : Color(uiColor: .secondarySystemFill), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: - Row

private struct NotificationRow: View {
    let notification: GootifNotification
    var showsService = true

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ServiceBadge(serviceName: notification.service, size: 36)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    if let color = Importance.color(notification.priority), notification.priority == "high" {
                        Circle().fill(color).frame(width: 7, height: 7)
                    }
                    if showsService {
                        Text(notification.service)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    if notification.kind != nil {
                        Text("Report")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .foregroundStyle(AppColors.accent)
                            .background(AppColors.accent.opacity(0.12), in: Capsule())
                    }
                    Spacer(minLength: 8)
                    Text(notification.timeLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Text(notification.title)
                    .font(.body.weight(.semibold))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !notification.body.isEmpty {
                    Text(notification.body)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .contentShape(Rectangle())
    }
}

extension GootifNotification {
    /// Clock time for today, short relative day otherwise — rows are already grouped by day.
    var timeLabel: String {
        guard let date = createdDate else { return relativeTime }
        return date.formatted(date: .omitted, time: .shortened)
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
