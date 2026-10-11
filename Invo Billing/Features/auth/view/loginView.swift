import SwiftUI

struct LoginView: View {
    @EnvironmentObject var viewModel: AuthViewModel
    @State private var showPassword = false

    var body: some View {
        ZStack {
            AuthBackdrop()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 32) {
                    AuthHeader(title: "Welcome back", subtitle: "Sign in to continue to Invo Billing")

                    VStack(alignment: .trailing, spacing: 10) {
                        AuthFieldGroup {
                            AuthInputRow(
                                icon: "envelope",
                                placeholder: "Email",
                                text: $viewModel.email,
                                keyboard: .emailAddress,
                                contentType: .username
                            )
                            AuthRowDivider()
                            AuthInputRow(
                                icon: "lock",
                                placeholder: "Password",
                                text: $viewModel.password,
                                contentType: .password,
                                isSecure: !showPassword
                            ) {
                                AuthRevealButton(isRevealed: $showPassword)
                            }
                        }

                        Button {
                            viewModel.resetEmail = viewModel.email
                            viewModel.showForgotPassword = true
                        } label: {
                            Text("Forgot password?")
                                .font(.footnote.weight(.medium))
                                .foregroundColor(AuthTheme.accent)
                        }
                    }

                    VStack(spacing: 12) {
                        if let error = viewModel.errorMessage {
                            AuthErrorBanner(message: error)
                        }

                        AuthPrimaryButton(title: "Sign in", isLoading: viewModel.isLoading) {
                            hideKeyboard()
                            Task { await viewModel.login() }
                        }

                        NavigationLink {
                            OTPLoginView().environmentObject(viewModel)
                        } label: {
                            AuthSecondaryLabel(icon: "iphone", title: "Sign in with OTP")
                        }
                    }

                    HStack(spacing: 4) {
                        Text("New to Invo Billing?")
                            .foregroundColor(AuthTheme.muted)
                        NavigationLink {
                            SignupView().environmentObject(viewModel)
                        } label: {
                            Text("Create account")
                                .fontWeight(.semibold)
                                .foregroundColor(AuthTheme.accent)
                        }
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 24)
                .padding(.top, 48)
                .padding(.bottom, 32)
            }
        }
        .navigationBarHidden(true)
        .onTapGesture { hideKeyboard() }
    }
}

// MARK: - Keyboard dismiss helper
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
    }
}
