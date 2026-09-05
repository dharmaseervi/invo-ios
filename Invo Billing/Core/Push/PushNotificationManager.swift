import UIKit
import UserNotifications

/// Bridges UIKit's push-registration callbacks into the app. SwiftUI's App lifecycle has
/// no equivalent for `didRegisterForRemoteNotificationsWithDeviceToken`, so this needs a
/// real AppDelegate wired in via @UIApplicationDelegateAdaptor.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let tokenString = deviceToken.map { String(format: "%02x", $0) }.joined()
        PushNotificationManager.shared.didReceiveDeviceToken(tokenString)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("Push registration failed:", error.localizedDescription)
    }

    // Show the banner/sound even while the app is in the foreground.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
}

@MainActor
final class PushNotificationManager {
    static let shared = PushNotificationManager()
    private init() {}

    private let tokenDefaultsKey = "apns_device_token"
    private var currentToken: String? {
        get { UserDefaults.standard.string(forKey: tokenDefaultsKey) }
        set { UserDefaults.standard.set(newValue, forKey: tokenDefaultsKey) }
    }

    /// Call once the user is signed in — asks for permission (a no-op if already
    /// answered) and, if granted, registers for a device token with APNs.
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            Task { @MainActor in
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    func didReceiveDeviceToken(_ token: String) {
        currentToken = token
        Task { await DeviceTokenService.shared.register(deviceToken: token) }
    }

    /// Call on logout so a stale token doesn't keep receiving another account's pushes.
    /// Captures the auth token synchronously — logout clears the keychain right after
    /// this returns, and the unregister call still needs to authenticate as this account.
    func unregisterCurrentToken() {
        guard let token = currentToken else { return }
        let authToken = KeychainManager.shared.loadToken()
        Task { await DeviceTokenService.shared.unregister(deviceToken: token, authToken: authToken) }
        currentToken = nil
    }
}
