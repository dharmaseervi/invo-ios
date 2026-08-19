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

    private static let companyKey = "selected_company_id"

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
                print("Auto-selecting first company:", first.id)
                self.selectedCompanyId = first.id  // store in state
                SessionManager.saveSelectedCompanyId(first.id)  // store in UserDefaults
            } else {
                print("⚠️ No companies found for user")
            }
        } catch {
            print("⚠️ Failed to load companies:", error.localizedDescription)
        }
    }

    func loadTokenFromKeychain() {
        if let saved = KeychainManager.shared.loadToken() {
            token = saved

            if isTokenExpired(saved) {
                logout()
            } else {
                isAuthenticated = true
                loadSelectedCompany()
            }
        } else {
            logout()
        }
    }

    func logout() {
        _ = KeychainManager.shared.deleteToken()
        token = nil
        isAuthenticated = false
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
