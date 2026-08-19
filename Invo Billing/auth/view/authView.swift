import SwiftUI

struct AuthView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showSignup = false
    
    var body: some View {
        NavigationStack {
            LoginView()
                .environmentObject(authViewModel)
                .navigationDestination(isPresented: $showSignup) {
                    SignupView()
                        .environmentObject(authViewModel)
                }
                .navigationDestination(isPresented: $authViewModel.requiresVerification) {
                    EmailVerificationView()
                        .environmentObject(authViewModel)
                }
                .navigationDestination(isPresented: $authViewModel.showForgotPassword) {
                    ForgotPasswordView()
                        .environmentObject(authViewModel)
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Sign up") { showSignup = true }
                    }
                }
        }
    }
}
