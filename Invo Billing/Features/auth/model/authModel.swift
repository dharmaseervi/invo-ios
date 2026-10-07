import Foundation

struct User: Codable {
    let id: Int
    let email: String
}

struct AuthResponse: Codable {
    let token: String
    let refresh_token: String?
    let session_id: String?
    let user: User
}

struct AuthErrorResponse: Codable, Error {
    let error: String
}

// Add to your existing models
struct OTPSendResponse: Codable {
    let message: String
    let expires_in: String
}

struct OTPVerifyResponse: Codable {
    let token: String
    let user: User
    let expires_in: Int
    let token_type: String
}

struct RegisterResponse: Codable {
    let message: String
    let user_id: Int
    let email: String
    let requires_verification: Bool
}

struct DeviceSession: Identifiable, Codable {
    let id: String
    let device_name: String
    let platform: String
    let ip_address: String
    let last_seen: String
    let created_at: String
}

struct SessionsListResponse: Codable {
    let sessions: [DeviceSession]
}

struct TokenRefreshResponse: Codable {
    let token: String
    let refresh_token: String
    let session_id: String?
    let expires_in: Double
}
