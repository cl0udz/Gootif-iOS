import SwiftUI

/// Reads through the visible list one notification per page: swipe sideways or
/// use the toolbar arrows to move to the next one without going back to the list.
struct NotificationPager: View {
    let store: NotificationStore
    @Binding var selection: GootifNotification?

    @State private var pageID: String?
    @State private var confirmingDelete = false
    @State private var isDeleting = false
    @State private var deleteError: String?

    init(store: NotificationStore, selection: Binding<GootifNotification?>) {
        self.store = store
        _selection = selection
        _pageID = State(initialValue: selection.wrappedValue?.id)
    }

    /// The filtered list, or just the selection when it is not in it (a push
    /// for an older notification).
    private var pages: [GootifNotification] {
        let visible = store.visible
        if let selection, !visible.contains(where: { $0.id == selection.id }) { return [selection] }
        return visible
    }

    private var index: Int? { pages.firstIndex { $0.id == selection?.id } }

    var body: some View {
        GeometryReader { proxy in
            let insets = proxy.safeAreaInsets
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(pages) { notification in
                        NotificationDetailView(notification: notification)
                            .safeAreaPadding(.leading, insets.leading)
                            .safeAreaPadding(.trailing, insets.trailing)
                            .containerRelativeFrame(.horizontal)
                            .id(notification.id)
                    }
                }
                .scrollTargetLayout()
            }
            // Pages span the full width, safe areas included, so the next page never
            // peeks in beside a side status bar; each page re-applies the side insets itself.
            .ignoresSafeArea(.container, edges: .horizontal)
        }
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        .scrollPosition(id: $pageID)
        .background(AppBackground())
        .onChange(of: pageID) { _, id in
            if let notification = pages.first(where: { $0.id == id }), notification.id != selection?.id {
                selection = notification
            }
        }
        .onChange(of: selection?.id) { _, id in
            if id != pageID { withAnimation { pageID = id } }
        }
        .navigationTitle(selection?.service ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .sensoryFeedback(.selection, trigger: selection?.id)
        .confirmationDialog("Delete this notification?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { Task { await deleteCurrent() } }
        }
        .alert("Could not delete", isPresented: Binding(
            get: { deleteError != nil }, set: { if !$0 { deleteError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: { Text(deleteError ?? "") }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button("Previous", systemImage: "chevron.up") { step(-1) }
                .disabled((index ?? 0) <= 0)
                .keyboardShortcut(.upArrow, modifiers: .command)
                .accessibilityIdentifier("pager-previous")
            Button("Next", systemImage: "chevron.down") { step(1) }
                .disabled(index.map { $0 >= pages.count - 1 } ?? true)
                .keyboardShortcut(.downArrow, modifiers: .command)
                .accessibilityIdentifier("pager-next")
            Menu("More", systemImage: "ellipsis") {
                if let index, pages.count > 1 {
                    Text("\(index + 1) of \(pages.count)")
                }
                if let url = selection?.primaryURL {
                    Link(destination: url) { Label("Open Link", systemImage: "arrow.up.right") }
                }
                Button("Delete", systemImage: "trash", role: .destructive) { confirmingDelete = true }
                    .disabled(isDeleting)
            }
            .accessibilityIdentifier("pager-more")
        }
    }

    private func step(_ offset: Int) {
        guard let index, pages.indices.contains(index + offset) else { return }
        selection = pages[index + offset]
    }

    private func deleteCurrent() async {
        guard let current = selection else { return }
        isDeleting = true
        let next = store.neighbor(of: current)
        do {
            try await store.delete(current)
            selection = next
        } catch {
            deleteError = error.localizedDescription
        }
        isDeleting = false
    }
}
