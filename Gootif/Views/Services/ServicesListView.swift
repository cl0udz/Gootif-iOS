import SwiftUI

struct ServicesListView: View {
    @Binding var selectedNotification: GootifNotification?
    @State private var services: [GootifService] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            AppBackground()

            if isLoading && services.isEmpty {
                ProgressView("Loading...")
            } else if let error = errorMessage, services.isEmpty {
                ContentUnavailableView {
                    Label("Error", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button("Retry") { Task { await load() } }
                }
            } else if services.isEmpty {
                ContentUnavailableView {
                    Label("No Services", systemImage: "square.stack.3d.up.slash")
                } description: {
                    Text("Services that send notifications will appear here.")
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(services) { service in
                            NavigationLink(value: service.name) {
                                ServiceRowView(service: service)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("service-\(service.name)")
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
            }
        }
        .navigationTitle("Services")
        .navigationDestination(for: String.self) { serviceName in
            ServiceNotificationsView(serviceName: serviceName, selectedNotification: $selectedNotification)
        }
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
            services = [GootifService(name: "premarket-brief", notificationCount: 1, lastNotificationAt: nil)]
            return
        }
        #endif
        isLoading = true
        errorMessage = nil
        do {
            services = try await APIClient.fetchServices()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

struct ServiceRowView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let service: GootifService

    var body: some View {
        HStack(spacing: 14) {
            ServiceBadge(serviceName: service.name)

            VStack(alignment: .leading, spacing: 4) {
                Text(service.name)
                    .font(.subheadline.weight(.semibold))

                (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4)) : AnyLayout(HStackLayout(spacing: 6))) {
                    Text("\(service.notificationCount) notification\(service.notificationCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let time = service.relativeTime {
                        Text("- \(time)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .floatingCard()
    }
}
