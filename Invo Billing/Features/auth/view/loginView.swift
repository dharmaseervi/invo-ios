import SwiftUI

struct LoginView: View {
    @EnvironmentObject var viewModel: AuthViewModel
    @State private var showPassword = false

    var body: some View {
        ZStack {
            AuthTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer().frame(height: 44)

                    // MARK: - Logo
                    VStack(spacing: 16) {
                        AuthLogo()
                        VStack(spacing: 5) {
                            Text("Invo Billing")
                                .font(.scaled(24, weight: .bold))
                                .foregroundColor(AuthTheme.foreground)
                            Text("GST invoicing for Indian businesses")
                                .font(.scaled(13))
                                .foregroundColor(AuthTheme.muted)
                        }
                    }
                    .padding(.bottom, 36)

                    // MARK: - Form
                    VStack(spacing: 16) {

                        AuthField(
                            label: "Email",
                            placeholder: "name@company.com",
                            text: $viewModel.email,
                            keyboard: .emailAddress
                        )

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Password")
                                    .font(.scaled(12.5, weight: .medium))
                                    .foregroundColor(AuthTheme.muted)
                                Spacer()
                                Button {
                                    viewModel.resetEmail = viewModel.email
                                    viewModel.showForgotPassword = true
                                } label: {
                                    Text("Forgot password?")
                                        .font(.scaled(12.5))
                                        .foregroundColor(AuthTheme.accentBright)
                                }
                            }

                            HStack(spacing: 10) {
                                Group {
                                    if showPassword {
                                        TextField("Enter your password", text: $viewModel.password)
                                    } else {
                                        SecureField("Enter your password", text: $viewModel.password)
                                    }
                                }
                                .font(.scaled(14))
                                .foregroundColor(AuthTheme.foreground)
                                .tint(AuthTheme.accentBright)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()

                                Button {
                                    showPassword.toggle()
                                } label: {
                                    Image(systemName: showPassword ? "eye.slash" : "eye")
                                        .font(.scaled(14))
                                        .foregroundColor(AuthTheme.muted)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(AuthTheme.field)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(AuthTheme.border, lineWidth: 1))
                            .cornerRadius(10)
                        }

                        if let error = viewModel.errorMessage {
                            AuthErrorBanner(message: error)
                        }

                        AuthPrimaryButton(title: "Sign in", isLoading: viewModel.isLoading) {
                            hideKeyboard()
                            Task { await viewModel.login() }
                        }
                        .padding(.top, 4)

                        HStack(spacing: 10) {
                            Rectangle().fill(AuthTheme.border).frame(height: 1)
                            Text("or continue with")
                                .font(.scaled(12))
                                .foregroundColor(AuthTheme.muted)
                                .fixedSize()
                            Rectangle().fill(AuthTheme.border).frame(height: 1)
                        }

                        NavigationLink {
                            OTPLoginView().environmentObject(viewModel)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "iphone")
                                    .font(.scaled(14))
                                Text("Login with OTP")
                                    .font(.scaled(14, weight: .medium))
                            }
                            .foregroundColor(AuthTheme.foreground)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(AuthTheme.field)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(AuthTheme.border, lineWidth: 1))
                            .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal, 24)

                    // Sign up
                    HStack(spacing: 4) {
                        Text("Don't have an account?")
                            .font(.scaled(13))
                            .foregroundColor(AuthTheme.muted)
                        NavigationLink {
                            SignupView().environmentObject(viewModel)
                        } label: {
                            Text("Sign up")
                                .font(.scaled(13, weight: .semibold))
                                .foregroundColor(AuthTheme.accentBright)
                        }
                    }
                    .padding(.top, 28)
                    .padding(.bottom, 40)
                }
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
