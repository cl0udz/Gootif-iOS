import Foundation
import Observation
import UserNotifications
#if os(iOS)
import UIKit
#else
import AppKit
import Security
#endif

/// Retains notification navigation across cold launches, before SwiftUI exists.
@MainActor
@Observable
final class PushNotifications {
    static let shared = PushNotifications()
    private(set) var enabled = UserDefaults.standard.object(forKey: "push.enabled") as? Bool ?? true
    private(set) var status = "Not registered yet"
    private(set) var refreshRevision = 0
    var pendingNotificationID: String?
    /// Sent in the push itself, so a tap can open it without waiting for the network.
    var pendingLink: URL?
    private var token: String?
    private var syncTask: Task<Void, Never>?

    private var installationID: String {
        if let id = UserDefaults.standard.string(forKey: "push.installationID") { return id }
        let id = UUID().uuidString.lowercased()
        UserDefaults.standard.set(id, forKey: "push.installationID")
        return id
    }

    func start() {
        syncTask?.cancel()
        syncTask = Task { await synchronize() }
    }

    func setEnabled(_ value: Bool) {
        enabled = value
        UserDefaults.standard.set(value, forKey: "push.enabled")
        start()
    }

    func registered(_ data: Data) {
        token = data.map { String(format: "%02x", $0) }.joined()
        syncTask?.cancel()
        syncTask = Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            guard !Task.isCancelled else { return }
            await uploadWithRetry(permissionDenied: settings.authorizationStatus == .denied)
        }
    }

    func registrationFailed(_ message: String) {
        status = "Registration failed: " + message
    }

    private func synchronize() async {
        let center = UNUserNotificationCenter.current()
        if !enabled {
            await uploadWithRetry()
            return
        }
        var settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            do { _ = try await center.requestAuthorization(options: [.alert, .sound, .badge]) }
            catch { status = error.localizedDescription; return }
            settings = await center.notificationSettings()
        }
        guard !Task.isCancelled else { return }
        if settings.authorizationStatus == .denied {
            await uploadWithRetry(permissionDenied: true)
            return
        }
        status = "Registering with Apple…"
        #if os(iOS)
        UIApplication.shared.registerForRemoteNotifications()
        #else
        NSApplication.shared.registerForRemoteNotifications()
        #endif
        // Register with Apple on every activation; its callback supplies the current token.
    }

    private func uploadWithRetry(permissionDenied: Bool = false) async {
        var delay = 5
        while !Task.isCancelled {
            let shouldEnable = enabled && !permissionDenied
            if shouldEnable && token == nil { return }
            do {
                try await APIClient.updatePushRegistration(
                    installationID: installationID, token: shouldEnable ? token : nil,
                    environment: Self.environment, enabled: shouldEnable
                )
                guard !Task.isCancelled else { return }
                status = permissionDenied ? "Notifications are blocked in system settings" :
                    (shouldEnable ? "Push notifications enabled" : "Push notifications disabled")
                return
            } catch {
                guard !Task.isCancelled else { return }
                status = "Push setup pending: " + error.localizedDescription
                do { try await Task.sleep(for: .seconds(delay)) }
                catch { return }
                delay = min(delay * 2, 300)
            }
        }
    }

    func received(id: String?, link: String? = nil, open: Bool) {
        refreshRevision += 1
        if open, let id, id.range(of: "^[0-9a-f]{32}$", options: .regularExpression) != nil {
            pendingLink = link.flatMap(URL.init(string:)).flatMap { url in
                ["http", "https"].contains(url.scheme?.lowercased()) ? url : nil
            }
            pendingNotificationID = id
            #if os(macOS)
            NSApplication.shared.activate(ignoringOtherApps: true)
            #endif
        }
    }

    /// Read the signed environment where possible; exported App Store builds use production.
    static var environment: String {
        #if os(macOS)
        if let task = SecTaskCreateFromSelf(nil),
           let value = SecTaskCopyValueForEntitlement(task, "com.apple.developer.aps-environment" as CFString, nil) as? String {
            return value
        }
        #else
        if let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
           let data = try? Data(contentsOf: url), let value = profileEnvironment(data) {
            return value
        }
        #endif
        return Bundle.main.object(forInfoDictionaryKey: "GootifPushEnvironment") as? String ?? "production"
    }

    static func profileEnvironment(_ data: Data) -> String? {
        guard let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex),
              let plist = try? PropertyListSerialization.propertyList(
                from: data.subdata(in: start.lowerBound..<end.upperBound), format: nil
              ) as? [String: Any],
              let entitlements = plist["Entitlements"] as? [String: Any],
              let value = entitlements["aps-environment"] as? String,
              ["development", "production"].contains(value) else { return nil }
        return value
    }
}

final class PushDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let id = notification.request.content.userInfo["notification_id"] as? String
        Task { @MainActor in PushNotifications.shared.received(id: id, open: false) }
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let id = userInfo["notification_id"] as? String
        let link = userInfo["link"] as? String
        let open = response.actionIdentifier == UNNotificationDefaultActionIdentifier
        Task { @MainActor in PushNotifications.shared.received(id: id, link: link, open: open) }
        completionHandler()
    }
}

#if os(iOS)
@MainActor
final class PushAppDelegate: NSObject, UIApplicationDelegate {
    private let notifications = PushDelegate()
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = notifications
        return true
    }
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        PushNotifications.shared.registered(deviceToken)
    }
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        PushNotifications.shared.registrationFailed(error.localizedDescription)
    }
}
#else
@MainActor
final class PushAppDelegate: NSObject, NSApplicationDelegate {
    private let notifications = PushDelegate()
    func applicationWillFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = notifications
    }
    func applicationDidBecomeActive(_ notification: Notification) {
        PushNotifications.shared.start()
    }
    func application(_ application: NSApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        PushNotifications.shared.registered(deviceToken)
    }
    func application(_ application: NSApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        PushNotifications.shared.registrationFailed(error.localizedDescription)
    }
}
#endif
