import SwiftUI

struct ContentView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var pendingPushLink: URL?
    @State private var selectedTab = 0
    @State private var recentPath: [String] = []
    @State private var servicesPath: [String] = []
    @State private var serviceNotification: GootifNotification?
    @State private var pushedNotification: GootifNotification?
    @State private var pushError: String?
    @State private var failedPushID: String?

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Recent", systemImage: "bell.fill", value: 0) {
                NotificationBrowser(path: $recentPath, selection: $pushedNotification, onDelete: didDelete) { selection in
                    RecentView(selectedNotification: selection)
                }
            }
            Tab("Services", systemImage: "square.stack.3d.up.fill", value: 1) {
                NotificationBrowser(path: $servicesPath, selection: $serviceNotification, onDelete: didDelete) { selection in
                    ServicesListView(selectedNotification: selection)
                }
            }
            Tab("Settings", systemImage: "gearshape.fill", value: 2) {
                NavigationStack {
                    SettingsView()
                }
            }
        }
        .tint(AppColors.accent)
        .task(id: PushNotifications.shared.pendingNotificationID) {
            guard let id = PushNotifications.shared.pendingNotificationID else { return }
            await openPush(id)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { openPendingPushLink() }
        }
        #if DEBUG
        .task {
            // UI-testing hook: behave as if a push for this fixture was tapped.
            let arguments = CommandLine.arguments
            if arguments.contains("-simulatePushTap") {
                didOpenPush(LayoutPreviewData.notifications[1], openLink: true)
            }
            if let flag = arguments.firstIndex(of: "-simulatePushLink"), flag + 1 < arguments.count {
                PushNotifications.shared.received(id: String(repeating: "0", count: 32), link: arguments[flag + 1], open: true)
            }
        }
        #endif
        .alert("Could not open notification", isPresented: Binding(
            get: { pushError != nil }, set: { if !$0 { pushError = nil } }
        )) {
            Button("Retry") { if let id = failedPushID { Task { await openPush(id) } } }
            Button("Cancel", role: .cancel) { failedPushID = nil }
        } message: { Text(pushError ?? "") }
    }

    private func didDelete() {
        pushedNotification = nil
        serviceNotification = nil
        PushNotifications.shared.received(id: nil, open: false)
    }

    private func openPush(_ id: String) async {
        selectedTab = 0
        recentPath = []
        let linkFromPush = PushNotifications.shared.pendingLink
        PushNotifications.shared.pendingLink = nil
        if let linkFromPush {
            pendingPushLink = linkFromPush
            openPendingPushLink()
        }
        do {
            let notification = try await APIClient.fetchNotification(id: id)
            guard !Task.isCancelled else { return }
            didOpenPush(notification, openLink: linkFromPush == nil)
            failedPushID = nil
        } catch {
            guard !Task.isCancelled else { return }
            // The link already did the job; the detail is only a nicety on return.
            if linkFromPush == nil {
                failedPushID = id
                pushError = error.localizedDescription
            }
        }
        if PushNotifications.shared.pendingNotificationID == id {
            PushNotifications.shared.pendingNotificationID = nil
        }
    }

    /// Tapping an alert goes straight to its link. The detail stays selected, so
    /// returning to the app shows it, and it is the fallback for link-free pushes.
    private func didOpenPush(_ notification: GootifNotification, openLink: Bool) {
        pushedNotification = notification
        if openLink {
            pendingPushLink = notification.primaryURL
            openPendingPushLink()
        }
    }

    /// A cold launch can get here before the scene is active, when opening a URL may fail.
    private func openPendingPushLink() {
        guard scenePhase == .active, let url = pendingPushLink else { return }
        pendingPushLink = nil
        openURL(url)
    }
}

/// Keep one navigation hierarchy across Duo's displays and iPad window sizes.
/// The system owns collapse, fold-aware column sizing, and bar placement.
private struct NotificationBrowser<Content: View>: View {
    @Binding var path: [String]
    @Binding var selection: GootifNotification?
    let onDelete: () -> Void
    @ViewBuilder var content: (Binding<GootifNotification?>) -> Content

    @State private var preferredColumn: NavigationSplitViewColumn = .sidebar

    var body: some View {
        NavigationSplitView(preferredCompactColumn: $preferredColumn) {
            NavigationStack(path: $path) {
                content(Binding(
                    get: { selection },
                    set: { notification in
                        selection = notification
                        // Also handles reopening the selected row after Back.
                        preferredColumn = notification == nil ? .sidebar : .detail
                    }
                ))
            }
        } detail: {
            if let notification = selection {
                NotificationDetailView(notification: notification, onDelete: onDelete, showsDone: false)
                    .id(notification.id)
            } else {
                ContentUnavailableView("Select a Notification", systemImage: "bell",
                                       description: Text("Choose an item to read its details or report."))
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onChange(of: selection?.id, initial: true) { _, id in
            preferredColumn = id == nil ? .sidebar : .detail
        }
    }
}
