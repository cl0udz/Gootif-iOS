import SwiftUI

struct ServiceNotificationsView: View {
    let serviceName: String

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
                    Text("No notifications from \(serviceName) yet.")
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(notifications) { notification in
                            NotificationCardView(notification: notification)
                                .onTapGesture {
                                    selectedNotification = notification
                                }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
            }
        }
        .navigationTitle(serviceName)
        .refreshable { await load() }
        .task { await load() }
        .sheet(item: $selectedNotification) { notification in
            NotificationDetailView(notification: notification) {
                notifications.removeAll { $0.id == notification.id }
                selectedNotification = nil
            }
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            notifications = try await APIClient.fetchNotifications(service: serviceName)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
