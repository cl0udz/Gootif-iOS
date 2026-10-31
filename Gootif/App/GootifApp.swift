import SwiftUI

@main
struct GootifApp: App {
    @UIApplicationDelegateAdaptor(PushAppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onChange(of: scenePhase, initial: true) { _, phase in
                    #if DEBUG
                    if CommandLine.arguments.contains("-layoutPreview") { return }
                    #endif
                    if phase == .active { PushNotifications.shared.start() }
                }
        }
    }
}
