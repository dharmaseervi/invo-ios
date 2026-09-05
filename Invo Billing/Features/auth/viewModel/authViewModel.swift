import Combine
import SwiftUI

@MainActor
final class AuthViewModel: ObservableObject {
    
    // MARK: - Login/Register fields
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var confirmPassword: String = ""
    
    // MARK: - UI State
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - OTP Login fields
    @Published var otpEmail: String = ""
    @Published var otpCode: String = ""
    @Published var otpSent: Bool = false
    @Published var showOTPLogin: Bool = false
    
    // MARK: - Email Verification fields
    @Published var requiresVerification = false
    @Published var verificationEmail = ""
    @Published var verificationCode = ""
    
    
    @Published var resetEmail = ""
    @Published var resetCode = ""
    @Published var resetNewPassword = ""
    @Published var resetConfirmPassword = ""
    @Published var resetCodeSent = false
    @Published var showForgotPassword = false
   
    
    private let authService = AuthService.shared
    private let keychain = KeychainManager.shared
    
    // MARK: - Login
    func login() async {
        guard !email.isEmpty && !password.isEmpty else {
            errorMessage = "Please enter email and password."
            return
        }
        
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            let resp = try await authService.login(
                email: email,
                password: password
            )
            _ = keychain.saveToken(resp.token)
            authService.setAuthToken(resp.token)
            resetFields()
            SessionManager.shared.loadTokenFromKeychain(freshLogin: true)
            
        } catch let authErr as AuthErrorResponse {
            // Handle unverified account
            if authErr.error.lowercased().contains("not verified") ||
                authErr.error.lowercased().contains("verify") {
                verificationEmail = email
                requiresVerification = true
            } else {
                // ❌ Wrong credentials or other error — just show error message
                errorMessage = authErr.error
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Register
    func register() async {
        guard !email.isEmpty, !password.isEmpty, password == confirmPassword else {
            errorMessage = "Please fill all fields correctly."
            return
        }
        
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            // Register returns message only — no token until verified
            _ = try await authService.register(email: email, password: password)
            verificationEmail = email
            requiresVerification = true
            resetFields()
            
        } catch let authErr as AuthErrorResponse {
            errorMessage = authErr.error
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Verify Email
    func verifyEmail() async {
        guard !verificationCode.isEmpty else {
            errorMessage = "Please enter the verification code"
            return
        }
        
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            let resp = try await authService.verifyEmail(
                email: verificationEmail,
                code: verificationCode
            )
            _ = keychain.saveToken(resp.token)
            authService.setAuthToken(resp.token)
            requiresVerification = false
            verificationCode = ""
            verificationEmail = ""
            SessionManager.shared.loadTokenFromKeychain(freshLogin: true)
            
        } catch let authErr as AuthErrorResponse {
            errorMessage = authErr.error
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Handle Unverified Login
    func handleUnverifiedLogin(email: String) {
        verificationEmail = email
        requiresVerification = true
    }
    
    // MARK: - Send OTP (for OTP login)
    func sendOTP() async {
        guard !otpEmail.isEmpty else {
            errorMessage = "Please enter your email"
            return
        }
        
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            _ = try await authService.sendOTP(email: otpEmail)
            otpSent = true
        } catch let authErr as AuthErrorResponse {
            errorMessage = authErr.error
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Verify OTP (for OTP login)
    func verifyOTP() async {
        guard !otpCode.isEmpty else {
            errorMessage = "Please enter the OTP"
            return
        }
        
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            let resp = try await authService.verifyOTP(
                email: otpEmail,
                code: otpCode
            )
            _ = keychain.saveToken(resp.token)
            authService.setAuthToken(resp.token)
            otpSent = false
            otpEmail = ""
            otpCode = ""
            SessionManager.shared.loadTokenFromKeychain(freshLogin: true)
            
        } catch let authErr as AuthErrorResponse {
            errorMessage = authErr.error
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Resend Verification
    func resendVerification() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await authService.resendVerification(email: verificationEmail)
            errorMessage = nil
        } catch let authErr as AuthErrorResponse {
            errorMessage = authErr.error
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Reset
    func resetFields() {
        email = ""
        password = ""
        confirmPassword = ""
        errorMessage = nil
    }
    
    // MARK: - Delete Account
    func deleteAccount() async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await authService.deleteAccount()
            _ = keychain.deleteToken()
            authService.setAuthToken(nil)
            SessionManager.shared.loadTokenFromKeychain(freshLogin: true)
            return true
        } catch let authErr as AuthErrorResponse {
            errorMessage = authErr.error
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
    
    func logout() {
        _ = KeychainManager.shared.deleteToken()
        AuthService.shared.setAuthToken(nil)
        SessionManager.shared.loadTokenFromKeychain(freshLogin: true)
    }
    
    
    // MARK: - Forgot Password
    func forgotPassword() async {
        guard !resetEmail.isEmpty else {
            errorMessage = "Please enter your email"
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            try await authService.forgotPassword(email: resetEmail)
            resetCodeSent = true
        } catch let authErr as AuthErrorResponse {
            errorMessage = authErr.error
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Reset Password
    func resetPassword() async {
        guard resetNewPassword == resetConfirmPassword else {
            errorMessage = "Passwords do not match"
            return
        }
        guard !resetCode.isEmpty else {
            errorMessage = "Please enter the reset code"
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            let resp = try await authService.resetPassword(
                email: resetEmail,
                code: resetCode,
                newPassword: resetNewPassword
            )
            _ = keychain.saveToken(resp.token)
            authService.setAuthToken(resp.token)
            showForgotPassword = false
            resetCodeSent = false
            resetEmail = ""
            resetCode = ""
            resetNewPassword = ""
            resetConfirmPassword = ""
            SessionManager.shared.loadTokenFromKeychain(freshLogin: true)
        } catch let authErr as AuthErrorResponse {
            errorMessage = authErr.error
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
