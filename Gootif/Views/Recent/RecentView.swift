import SwiftUI

struct RecentView: View {
    @State private var notifications: [GootifNotification] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedNotification: GootifNotification?

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
                            ServiceGroupCardView(group: group) { notification in
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
        .task {
            await load()
            // UI-testing hook: auto-open the newest rich report.
            if CommandLine.arguments.contains("-openLatestReport") {
                selectedNotification = notifications.first { $0.kind != nil }
            }
        }
        .sheet(item: $selectedNotification) { notification in
            NotificationDetailView(notification: notification) {
                notifications.removeAll { $0.id == notification.id }
                selectedNotification = nil
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
