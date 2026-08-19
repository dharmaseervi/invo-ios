//
//  authService.swift
//  invo
//
//  Created by dharmaseervi on 11/15/25.
//

import Foundation


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
    
    func login(email:String , password:String) async throws -> AuthResponse{
        guard let url = URL(string: "\(baseURL)/login") else { throw URLError(.badURL) }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["email": email, "password": password]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body, options: []) else {
            fatalError("Couldn't serialize JSON")
        }
        
        request.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            fatalError("Invalid response")
        }
        switch httpResponse.statusCode {
        case 200...299:
            return try JSONDecoder().decode(AuthResponse.self, from: data)
        default:
            let error = try? JSONDecoder().decode(AuthErrorResponse.self, from: data)
            throw error ?? AuthErrorResponse(error: "Unknown error")
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

