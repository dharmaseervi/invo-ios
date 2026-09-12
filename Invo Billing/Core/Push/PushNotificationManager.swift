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

    /// Asks for permission and, if granted, registers for a device token.
    ///
    /// Called when someone turns notifications on in Settings, not at sign-in. Apple's
    /// guidance is to "wait to request permission until people actually use an app
    /// feature that requires access" (privacy.md), and asking the moment an account is
    /// created — before there is a single invoice to be reminded about — is the prompt
    /// people dismiss without reading.
    @discardableResult
    func requestAuthorization() async -> Bool {
        let granted = (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        if granted {
            UIApplication.shared.registerForRemoteNotifications()
        }
        return granted
    }

    /// Whether the person has already been asked, and what they said.
    func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Re-registers for a token on launch when permission is already granted, so a
    /// reinstall or a token rotation does not silently stop delivering.
    func registerIfAlreadyAuthorized() async {
        if await authorizationStatus() == .authorized {
            UIApplication.shared.registerForRemoteNotifications()
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
