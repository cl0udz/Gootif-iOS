import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Recent", systemImage: "bell.fill", value: 0) {
                NavigationStack {
                    RecentView()
                }
            }
            Tab("Services", systemImage: "square.stack.3d.up.fill", value: 1) {
                NavigationStack {
                    ServicesListView()
                }
            }
            Tab("Settings", systemImage: "gearshape.fill", value: 2) {
                NavigationStack {
                    SettingsView()
                }
            }
        }
        .tint(AppColors.accent)
    }
}
