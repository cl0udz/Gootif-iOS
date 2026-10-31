import SwiftUI

struct ServiceNotificationsView: View {
    let serviceName: String

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
                    Text("No notifications from \(serviceName) yet.")
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(notifications) { notification in
                            HStack(spacing: 4) {
                                Button {
                                    selectedNotification = notification
                                } label: {
                                    NotificationCardView(notification: notification)
                                        .notificationSelection(selectedNotification?.id == notification.id)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("service-notification-\(notification.id)")

                                if let url = notification.primaryURL {
                                    RowOpenLinkButton(url: url)
                                }
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Refresh", systemImage: "arrow.clockwise") { Task { await load() } }
                    .disabled(isLoading)
                    .keyboardShortcut("r", modifiers: .command)
            }
        }
        .task(id: PushNotifications.shared.refreshRevision) { await load() }

    }

    private func load() async {
        #if DEBUG
        if CommandLine.arguments.contains("-layoutPreview") {
            notifications = LayoutPreviewData.notifications.filter { $0.service == serviceName }
            return
        }
        #endif
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
