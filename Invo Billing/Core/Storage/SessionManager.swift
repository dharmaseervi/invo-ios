import Combine
//
//  SessionManager.swift
//  invo
//
//  Created by dharmaseervi on 11/18/25.
//
import Foundation

final class SessionManager: ObservableObject {
    static let shared = SessionManager()

    @Published var isAuthenticated = false
    @Published var token: String?
    /// True once the initial keychain read is done. RootView waits on this to avoid
    /// a one-frame flash of the login screen on every launch with a valid session.
    @Published var sessionReady = false

    @Published var selectedCompanyId: Int? = nil {
        didSet {
            SessionManager.saveSelectedCompanyId(selectedCompanyId)
            if selectedCompanyId != oldValue {
                Task { await refreshCompanyRole() }
            }
        }
    }

    /// What this account is to the company currently selected.
    ///
    /// Only decides what the app draws. Every one of these is enforced on the server,
    /// which answers 403 whatever this says — so the cost of getting it wrong is a
    /// screen that shouldn't be offered, not a door left open.
    ///
    /// Owner until told otherwise: before staff existed every account owned its shop,
    /// and an app that guessed "staff" would hide a person's own business from them
    /// while the server was perfectly willing to show it.
    @Published private(set) var companyRole: MemberRole = .owner

    /// Reads the role back from the server's company list. Called when the selected
    /// company changes and after signing in, because a role can be changed by the
    /// owner while somebody is using the app.
    @MainActor
    func refreshCompanyRole() async {
        guard let companyID = selectedCompanyId else {
            companyRole = .owner
            return
        }
        do {
            let companies = try await CompanyService().getMyCompany()
            guard let mine = companies?.first(where: { $0.id == companyID }) else { return }
            // A server that does not send a role at all is one from before staff
            // existed, where everybody is the owner of what they can see.
            companyRole = mine.role.map { MemberRole($0) } ?? .owner
        } catch {
            // Leave it as it was. A failed refresh should not quietly take screens
            // away from somebody mid-task.
        }
    }

    // MARK: - Biometric lock
    @Published var isBiometricLockEnabled: Bool = UserDefaults.standard.bool(forKey: SessionManager.biometricKey) {
        didSet {
            UserDefaults.standard.set(isBiometricLockEnabled, forKey: SessionManager.biometricKey)
        }
    }
    /// True once the current app session has passed the lock screen (biometric or fresh login).
    @Published var isUnlocked: Bool = true

    func lock() {
        guard isBiometricLockEnabled, isAuthenticated else { return }
        isUnlocked = false
    }

    @MainActor
    func unlockWithBiometrics() async -> Bool {
        let success = await BiometricAuthService.authenticate(
            reason: "Sign in to Invo Billing"
        )
        if success { isUnlocked = true }
        return success
    }

    private static let companyKey = "selected_company_id"
    private static let biometricKey = "biometric_lock_enabled"

    func loadSelectedCompany() {
        let id = UserDefaults.standard.integer(
            forKey: SessionManager.companyKey
        )
        if id != 0 {  // 0 means no saved company
            self.selectedCompanyId = id
        } else {
            Task {
                await self.loadFirstCompanyAsDefault()
            }
        }
    }

    @MainActor
    private func loadFirstCompanyAsDefault() async {
        do {
            let companies = try await CompanyService().getMyCompany()

            if let first = companies?.first {
                self.selectedCompanyId = first.id
                SessionManager.saveSelectedCompanyId(first.id)
                self.companyRole = first.role.map { MemberRole($0) } ?? .owner
            }
        } catch {
            // No company yet, or request failed — user will be prompted to create one
        }
    }

    /// - Parameter freshLogin: true right after the user just typed a password/OTP and succeeded —
    ///   skips the biometric gate since they already proved identity this run.
    func loadTokenFromKeychain(freshLogin: Bool = false) {
        if let saved = KeychainManager.shared.loadToken() {
            token = saved

            if isTokenExpired(saved) {
                // Access token expired — try refreshing silently before giving up.
                // sessionReady is set inside tryRefreshOrLogout when it finishes.
                Task { await tryRefreshOrLogout(freshLogin: freshLogin) }
            } else {
                isAuthenticated = true
                isUnlocked = freshLogin || !isBiometricLockEnabled
                sessionReady = true
                loadSelectedCompany()
                // Proactively refresh when within 24 h of expiry.
                if tokenExpiresWithin(saved, seconds: 86_400) {
                    Task { try? await AuthService.shared.refreshAccessToken() }
                }
            }
        } else {
            // No access token — try the refresh token path before forcing a login.
            Task { await tryRefreshOrLogout(freshLogin: freshLogin) }
        }
    }

    @MainActor
    private func tryRefreshOrLogout(freshLogin: Bool) async {
        do {
            let resp = try await AuthService.shared.refreshAccessToken()
            token = resp.token
            isAuthenticated = true
            isUnlocked = freshLogin || !isBiometricLockEnabled
            sessionReady = true
            loadSelectedCompany()
        } catch {
            logout()
            sessionReady = true
        }
    }

    func logout() {
        PushNotificationManager.shared.unregisterCurrentToken()

        let authToken = KeychainManager.shared.loadToken()
        Task { try? await userService.shared.logoutRequest(authToken: authToken) }

        _ = KeychainManager.shared.deleteToken()
        _ = KeychainManager.shared.deleteRefreshToken()
        _ = KeychainManager.shared.deleteSessionID()
        token = nil
        isAuthenticated = false
        isUnlocked = true
        sessionReady = true
        selectedCompanyId = nil
        Self.saveSelectedCompanyId(nil)
    }

    static func saveSelectedCompanyId(_ id: Int?) {
        if let id = id {
            UserDefaults.standard.set(id, forKey: companyKey)
        } else {
            UserDefaults.standard.removeObject(forKey: companyKey)
        }
    }
}

func tokenExpiresWithin(_ token: String, seconds: TimeInterval) -> Bool {
    let parts = token.split(separator: ".")
    if parts.count != 3 { return true }
    var padded = String(parts[1])
    padded = padded.padding(toLength: ((padded.count + 3) / 4) * 4, withPad: "=", startingAt: 0)
    guard let data = Data(base64Encoded: padded),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let exp = json["exp"] as? Double
    else { return true }
    return Date().timeIntervalSince1970 > exp - seconds
}

func isTokenExpired(_ token: String) -> Bool {
    let parts = token.split(separator: ".")
    if parts.count != 3 { return true }

    let payloadPart = parts[1]
    var padded = String(payloadPart)
    padded = padded.padding(
        toLength: ((padded.count + 3) / 4) * 4,
        withPad: "=",
        startingAt: 0
    )

    guard let payloadData = Data(base64Encoded: padded),
        let json = try? JSONSerialization.jsonObject(with: payloadData)
            as? [String: Any],
        let exp = json["exp"] as? Double
    else {
        return true
    }

    return Date().timeIntervalSince1970 > exp
}
