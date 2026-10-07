//
//  authService.swift
//  invo
//
//  Created by dharmaseervi on 11/15/25.
//

import Foundation
import UIKit

class AuthService {
    
    static let shared = AuthService()
    
    private let baseURL = AppEnvironment.baseURL
    
    private var authToken: String?
    
    func setAuthToken(_ token: String?) {
        authToken = token
    }
    
    func authorizedRequest(_ url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = KeychainManager.shared.loadToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
       

        return request
    }

    
    
    func register(email: String, password: String) async throws -> RegisterResponse {
        guard let url = URL(string: "\(baseURL)/register") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["email": email, "password": password]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        switch http.statusCode {
        case 200...299:
            return try JSONDecoder().decode(RegisterResponse.self, from: data)
        default:
            let error = try? JSONDecoder().decode(AuthErrorResponse.self, from: data)
            throw error ?? AuthErrorResponse(error: "Registration failed")
        }
    
    }
    
    func login(email: String, password: String) async throws -> AuthResponse {
        guard let url = URL(string: "\(baseURL)/login") else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "email": email,
            "password": password,
            "device_name": UIDevice.current.name,
            "platform": "ios"
        ]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        switch httpResponse.statusCode {
        case 200...299:
            let decoded = try JSONDecoder().decode(AuthResponse.self, from: data)
            if let rt = decoded.refresh_token { _ = KeychainManager.shared.saveRefreshToken(rt) }
            if let sid = decoded.session_id   { _ = KeychainManager.shared.saveSessionID(sid) }
            return decoded
        default:
            let error = try? JSONDecoder().decode(AuthErrorResponse.self, from: data)
            throw error ?? AuthErrorResponse(error: "Unknown error")
        }
    }

    func refreshAccessToken() async throws -> TokenRefreshResponse {
        guard let refreshToken = KeychainManager.shared.loadRefreshToken() else {
            throw AuthErrorResponse(error: "No refresh token")
        }
        guard let url = URL(string: "\(baseURL)/auth/token/refresh") else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["refresh_token": refreshToken])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        switch http.statusCode {
        case 200...299:
            let decoded = try JSONDecoder().decode(TokenRefreshResponse.self, from: data)
            _ = KeychainManager.shared.saveToken(decoded.token)
            _ = KeychainManager.shared.saveRefreshToken(decoded.refresh_token)
            if let sid = decoded.session_id { _ = KeychainManager.shared.saveSessionID(sid) }
            return decoded
        default:
            let error = try? JSONDecoder().decode(AuthErrorResponse.self, from: data)
            throw error ?? AuthErrorResponse(error: "Token refresh failed")
        }
    }

    func fetchSessions() async throws -> [DeviceSession] {
        guard let url = URL(string: "\(baseURL)/auth/sessions") else { throw URLError(.badURL) }
        let request = authorizedRequest(url)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(SessionsListResponse.self, from: data).sessions
    }

    func revokeSession(id: String) async throws {
        guard let url = URL(string: "\(baseURL)/auth/sessions/\(id)") else { throw URLError(.badURL) }
        var request = authorizedRequest(url)
        request.httpMethod = "DELETE"
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    func revokeAllOtherSessions() async throws {
        let keepID = KeychainManager.shared.loadSessionID() ?? ""
        let query = keepID.isEmpty ? "" : "?keep=\(keepID)"
        guard let url = URL(string: "\(baseURL)/auth/sessions\(query)") else { throw URLError(.badURL) }
        var request = authorizedRequest(url)
        request.httpMethod = "DELETE"
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
    
    
    // send otp and verify otp 
    
    func sendOTP(email: String) async throws -> OTPSendResponse {
        guard let url = URL(string: "\(baseURL)/send-otp") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["email": email])
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        switch http.statusCode {
        case 200...299:
            return try JSONDecoder().decode(OTPSendResponse.self, from: data)
        default:
            let error = try? JSONDecoder().decode(AuthErrorResponse.self, from: data)
            throw error ?? AuthErrorResponse(error: "Failed to send OTP")
        }
    }
    
    func verifyOTP(email: String, code: String) async throws -> OTPVerifyResponse {
        guard let url = URL(string: "\(baseURL)/verify-otp") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["email": email, "code": code]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        switch http.statusCode {
        case 200...299:
            return try JSONDecoder().decode(OTPVerifyResponse.self, from: data)
        default:
            let error = try? JSONDecoder().decode(AuthErrorResponse.self, from: data)
            throw error ?? AuthErrorResponse(error: "Invalid OTP")
        }
    }
    
    func verifyEmail(email: String, code: String) async throws -> AuthResponse {
        guard let url = URL(string: "\(baseURL)/verify-email") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["email": email, "code": code]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        switch http.statusCode {
        case 200...299:
            return try JSONDecoder().decode(AuthResponse.self, from: data)
        default:
            let error = try? JSONDecoder().decode(AuthErrorResponse.self, from: data)
            throw error ?? AuthErrorResponse(error: "Verification failed")
        }
    }
    
    func resendVerification(email: String) async throws {
        guard let url = URL(string: "\(baseURL)/resend-verification") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["email": email])
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        if http.statusCode >= 400 {
            let error = try? JSONDecoder().decode(AuthErrorResponse.self, from: data)
            throw error ?? AuthErrorResponse(error: "Failed to resend code")
        }
    }
    
    func forgotPassword(email: String) async throws {
        guard let url = URL(string: "\(baseURL)/forgot-password") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["email": email])
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
    
    /// Deletes the account, confirming with the password.
    ///
    /// Deleting is the most destructive thing this app can do, and a bearer token was
    /// the only thing standing in front of it — so a phone picked up off a counter was
    /// enough to wipe a business's books. The password proves the person holding the
    /// token is the owner.
    func deleteAccount(password: String) async throws {
        guard let url = URL(string: "\(baseURL)/account") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        guard let token = KeychainManager.shared.loadToken() else {
            throw AuthErrorResponse(error: "No active session")
        }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(["password": password])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        if http.statusCode != 200 {
            let error = try? JSONDecoder().decode(AuthErrorResponse.self, from: data)
            throw error ?? AuthErrorResponse(error: "Failed to delete account")
        }
    }

    func resetPassword(email: String, code: String, newPassword: String) async throws -> AuthResponse {
        guard let url = URL(string: "\(baseURL)/reset-password") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["email": email, "code": code, "new_password": newPassword]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        switch http.statusCode {
        case 200...299:
            return try JSONDecoder().decode(AuthResponse.self, from: data)
        default:
            let error = try? JSONDecoder().decode(AuthErrorResponse.self, from: data)
            throw error ?? AuthErrorResponse(error: "Reset failed")
        }
    }
    
}

