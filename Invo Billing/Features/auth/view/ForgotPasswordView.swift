import SwiftUI

struct ForgotPasswordView: View {
    @EnvironmentObject var viewModel: AuthViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var showPassword = false
    @State private var showConfirm = false

    var passwordsMatch: Bool {
        !viewModel.resetConfirmPassword.isEmpty &&
        viewModel.resetNewPassword == viewModel.resetConfirmPassword
    }

    private var showMismatch: Bool {
        !viewModel.resetConfirmPassword.isEmpty && !passwordsMatch
    }

    var body: some View {
        ZStack {
            AuthBackdrop()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 32) {
                    AuthBackButton {
                        viewModel.resetCodeSent = false
                        viewModel.resetCode = ""
                        viewModel.errorMessage = nil
                        presentationMode.wrappedValue.dismiss()
                    }

                    AuthHeader(
                        title: viewModel.resetCodeSent ? "Reset your password" : "Forgot password?",
                        subtitle: viewModel.resetCodeSent
                            ? "Enter the code sent to \(viewModel.resetEmail) and choose a new password"
                            : "Enter your email and we'll send you a reset code",
                        symbol: viewModel.resetCodeSent ? "lock.rotation" : "key"
                    )

                    if viewModel.resetCodeSent {
                        VStack(alignment: .leading, spacing: 12) {
                            AuthCodeField(code: $viewModel.resetCode)
                            AuthHint(icon: "clock", text: "Code expires in 10 minutes")
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            AuthFieldGroup {
                                AuthInputRow(
                                    icon: "lock",
                                    placeholder: "New password",
                                    text: $viewModel.resetNewPassword,
                                    contentType: .newPassword,
                                    isSecure: !showPassword
                                ) {
                                    AuthRevealButton(isRevealed: $showPassword)
                                }
                                AuthRowDivider()
                                AuthInputRow(
                                    icon: "lock.rotation",
                                    placeholder: "Confirm new password",
                                    text: $viewModel.resetConfirmPassword,
                                    contentType: .newPassword,
                                    isSecure: !showConfirm
                                ) {
                                    if viewModel.resetConfirmPassword.isEmpty {
                                        AuthRevealButton(isRevealed: $showConfirm)
                                    } else {
                                        Image(systemName: passwordsMatch ? "checkmark.circle.fill" : "xmark.circle.fill")
                                            .font(.subheadline)
                                            .foregroundColor(passwordsMatch ? AuthTheme.success : AuthTheme.destructive)
                                            .frame(width: 32, height: 32)
                                            .accessibilityLabel(passwordsMatch ? "Passwords match" : "Passwords do not match")
                                    }
                                }
                            }

                            if showMismatch {
                                Text("Passwords don't match")
                                    .font(.caption)
                                    .foregroundColor(AuthTheme.destructive)
                                    .padding(.horizontal, 4)
                            }
                        }
                    } else {
                        AuthFieldGroup {
                            AuthInputRow(
                                icon: "envelope",
                                placeholder: "Email",
                                text: $viewModel.resetEmail,
                                keyboard: .emailAddress,
                                contentType: .username
                            )
                        }
                    }

                    VStack(spacing: 12) {
                        if let error = viewModel.errorMessage {
                            AuthErrorBanner(message: error)
                        }

                        AuthPrimaryButton(
                            title: viewModel.resetCodeSent ? "Reset password" : "Send code",
                            isLoading: viewModel.isLoading
                        ) {
                            hideKeyboard()
                            if viewModel.resetCodeSent {
                                guard passwordsMatch else {
                                    viewModel.errorMessage = "Passwords do not match"
                                    return
                                }
                            }
                            Task {
                                if viewModel.resetCodeSent {
                                    await viewModel.resetPassword()
                                } else {
                                    await viewModel.forgotPassword()
                                }
                            }
                        }

                        if viewModel.resetCodeSent {
                            HStack(spacing: 24) {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        viewModel.resetCodeSent = false
                                        viewModel.resetCode = ""
                                        viewModel.errorMessage = nil
                                    }
                                } label: {
                                    Text("Change email")
                                        .foregroundColor(AuthTheme.muted)
                                }

                                Button {
                                    Task { await viewModel.forgotPassword() }
                                } label: {
                                    Text("Resend code")
                                        .fontWeight(.semibold)
                                        .foregroundColor(AuthTheme.accent)
                                }
                            }
                            .font(.subheadline)
                            .padding(.top, 8)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
        .navigationBarHidden(true)
        .onTapGesture { hideKeyboard() }
    }
}

#Preview {
    ForgotPasswordView()
        .environmentObject(AuthViewModel())
}
