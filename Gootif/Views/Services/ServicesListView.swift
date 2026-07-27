import SwiftUI

struct ServicesListView: View {
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
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
            }
        }
        .navigationTitle("Services")
        .navigationDestination(for: String.self) { serviceName in
            ServiceNotificationsView(serviceName: serviceName)
        }
        .refreshable { await load() }
        .task { await load() }
    }

    private func load() async {
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
    let service: GootifService

    var body: some View {
        HStack(spacing: 14) {
            ServiceBadge(serviceName: service.name)

            VStack(alignment: .leading, spacing: 4) {
                Text(service.name)
                    .font(.subheadline.weight(.semibold))

                HStack(spacing: 6) {
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
