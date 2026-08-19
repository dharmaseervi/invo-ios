//
//  userService.swift
//  invo
//
//  Created by dharmaseervi on 11/16/25.
//

import Foundation

class userService {
    static let shared = userService()
    private init() {}

    private let baseURL = AppEnvironment.baseURL

    // MARK: - Fetch user profile (authorized)
    func getUserProfile() async throws -> UserProfile {

        guard let url = URL(string: "\(baseURL)/profile") else {
            throw URLError(.badURL)
        }

        // Build authorized request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Attach Bearer token
        if let token = KeychainManager.shared.loadToken() {
            request.setValue(
                "Bearer \(token)",
                forHTTPHeaderField: "Authorization"
            )
            print("token", token)
        } else {
            throw URLError(.userAuthenticationRequired)
        }

        // Make request
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        switch http.statusCode {
        case 200:
            return try JSONDecoder().decode(UserProfile.self, from: data)
        case 401:
            throw URLError(.userAuthenticationRequired)
        default:
            throw URLError(.cannotParseResponse)
        }
    }

    //     MARK: - LOGOUT REQUEST
    func logoutRequest() async throws {
        guard let url = URL(string: "\(baseURL)/logout") else {
            throw URLError(.badURL)
        }
        var request = AuthService.shared.authorizedRequest(url)
        request.httpMethod = "POST"

        _ = try await URLSession.shared.data(for: request)
    }
}
