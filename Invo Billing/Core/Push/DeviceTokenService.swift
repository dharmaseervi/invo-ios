import Foundation

final class DeviceTokenService {
    static let shared = DeviceTokenService()
    private init() {}

    private let baseURL = AppEnvironment.baseURL

    private func authorizedRequest(url: URL, method: String, authToken: String?) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let authToken {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    func register(deviceToken: String) async {
        guard let url = URL(string: "\(baseURL)/device-tokens") else { return }
        var request = authorizedRequest(url: url, method: "POST", authToken: KeychainManager.shared.loadToken())
        request.httpBody = try? JSONEncoder().encode(["token": deviceToken])
        _ = try? await URLSession.shared.data(for: request)
    }

    /// `authToken` is captured by the caller *before* logout clears the keychain,
    /// since this call needs to authenticate as the account being signed out of.
    func unregister(deviceToken: String, authToken: String?) async {
        guard let url = URL(string: "\(baseURL)/device-tokens") else { return }
        var request = authorizedRequest(url: url, method: "DELETE", authToken: authToken)
        request.httpBody = try? JSONEncoder().encode(["token": deviceToken])
        _ = try? await URLSession.shared.data(for: request)
    }
}
