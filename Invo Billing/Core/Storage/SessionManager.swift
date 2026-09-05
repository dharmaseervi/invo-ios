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

    @Published var selectedCompanyId: Int? = nil {
        didSet {
            SessionManager.saveSelectedCompanyId(selectedCompanyId)
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
                logout()
            } else {
                isAuthenticated = true
                isUnlocked = freshLogin || !isBiometricLockEnabled
                loadSelectedCompany()
            }
        } else {
            logout()
        }
    }

    func logout() {
        PushNotificationManager.shared.unregisterCurrentToken()

        // Best-effort server-side logout — captured before the keychain token is
        // cleared below, since this call needs to authenticate as the account
        // being signed out of.
        let authToken = KeychainManager.shared.loadToken()
        Task { try? await userService.shared.logoutRequest(authToken: authToken) }

        _ = KeychainManager.shared.deleteToken()
        token = nil
        isAuthenticated = false
        isUnlocked = true
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
