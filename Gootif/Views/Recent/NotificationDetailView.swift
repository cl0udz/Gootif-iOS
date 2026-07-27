import SwiftUI

struct NotificationDetailView: View {
    let notification: GootifNotification
    var onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var isDeleting = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                content
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var navigationTitle: String {
        notification.kind == nil ? "Details" : "Report"
    }

    @ViewBuilder
    private var content: some View {
        switch notification.kind {
        case .newsFeed:
            NewsReportView(notification: notification, onDelete: onDelete)
        case .taskDigest:
            TaskDigestView(notification: notification, onDelete: onDelete)
        case .securityFeed:
            SecurityFeedView(notification: notification, onDelete: onDelete)
        case nil:
            genericContent
        }
    }

    @ViewBuilder
    private var genericContent: some View {
        ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header
                        HStack(spacing: 14) {
                            ServiceBadge(serviceName: notification.service, size: 52)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(notification.service)
                                    .font(.headline)
                                    .foregroundStyle(AppColors.accent)
                                HStack(spacing: 8) {
                                    PriorityPill(priority: notification.priority)
                                    Text(notification.relativeTime)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        // Title
                        Text(notification.title)
                            .font(.title2.bold())

                        // Body
                        if !notification.body.isEmpty {
                            Text(notification.body)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }

                        // Metadata
                        if !notification.metadata.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Details")
                                    .font(.headline)

                                ForEach(notification.metadata.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                                    HStack {
                                        Text(key)
                                            .font(.caption.weight(.medium))
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Text(value.displayString)
                                            .font(.caption.monospaced())
                                    }
                                }
                            }
                            .floatingCard()
                        }

                        // Timestamp
                        if let date = notification.createdDate {
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundStyle(.secondary)
                                Text(date.formatted(date: .long, time: .standard))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        // Delete
                        Button(role: .destructive) {
                            Task { await deleteNotification() }
                        } label: {
                            HStack {
                                if isDeleting {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "trash")
                                }
                                Text("Delete Notification")
                            }
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppColors.negative, in: Capsule())
                        }
                        .disabled(isDeleting)
                        .padding(.top, 8)
                    }
                    .padding()
                }
            }

    private func deleteNotification() async {
        isDeleting = true
        do {
            try await APIClient.deleteNotification(id: notification.id)
            onDelete?()
            dismiss()
        } catch {
            isDeleting = false
        }
    }
}

struct PriorityPill: View {
    let priority: String

    private var color: Color {
        switch priority {
        case "high": return AppColors.negative
        case "medium": return AppColors.warning
        default: return .secondary
        }
    }

    var body: some View {
        Text(priority.capitalized)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.2))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}
