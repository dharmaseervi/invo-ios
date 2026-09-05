import SwiftUI

struct AuthView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        NavigationStack {
            LoginView()
                .environmentObject(authViewModel)
                .navigationDestination(isPresented: $authViewModel.requiresVerification) {
                    EmailVerificationView()
                        .environmentObject(authViewModel)
                }
                .navigationDestination(isPresented: $authViewModel.showForgotPassword) {
                    ForgotPasswordView()
                        .environmentObject(authViewModel)
                }
        }
    }
}
