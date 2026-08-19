import Foundation

struct User: Codable {
    let id: Int
    let email: String
}

struct AuthResponse: Codable {
    let token: String
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
