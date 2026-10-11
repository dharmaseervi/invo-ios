import SwiftUI

// MARK: - Signup View
struct SignupView: View {
    @EnvironmentObject var viewModel: AuthViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var showPassword = false
    @State private var showConfirm = false

    var passwordsMatch: Bool {
        !viewModel.confirmPassword.isEmpty &&
        viewModel.password == viewModel.confirmPassword
    }

    var passwordStrength: Int {
        let p = viewModel.password
        guard !p.isEmpty else { return 0 }
        var score = 0
        if p.count >= 8 { score += 1 }
        if p.rangeOfCharacter(from: .uppercaseLetters) != nil { score += 1 }
        if p.rangeOfCharacter(from: .decimalDigits) != nil { score += 1 }
        if p.rangeOfCharacter(from: .punctuationCharacters) != nil { score += 1 }
        return score
    }

    var strengthLabel: String {
        switch passwordStrength {
        case 0, 1: return "Weak"
        case 2:    return "Fair"
        case 3:    return "Good"
        default:   return "Strong"
        }
    }

    func strengthColor(for index: Int) -> Color {
        let filled = index < passwordStrength
        if !filled { return AuthTheme.border }
        switch passwordStrength {
        case 0, 1: return AuthTheme.destructive
        case 2:    return .sWarning
        default:   return AuthTheme.success
        }
    }

    private var showMismatch: Bool {
        !viewModel.confirmPassword.isEmpty && !passwordsMatch
    }

    var body: some View {
        ZStack {
            AuthBackdrop()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 32) {
                    AuthHeader(title: "Create account", subtitle: "Start managing your invoices")

                    VStack(alignment: .leading, spacing: 10) {
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
                                contentType: .newPassword,
                                isSecure: !showPassword
                            ) {
                                AuthRevealButton(isRevealed: $showPassword)
                            }
                            AuthRowDivider()
                            AuthInputRow(
                                icon: "lock.rotation",
                                placeholder: "Confirm password",
                                text: $viewModel.confirmPassword,
                                contentType: .newPassword,
                                isSecure: !showConfirm
                            ) {
                                if viewModel.confirmPassword.isEmpty {
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

                        if !viewModel.password.isEmpty {
                            HStack(spacing: 10) {
                                HStack(spacing: 4) {
                                    ForEach(0..<4, id: \.self) { i in
                                        Capsule()
                                            .fill(strengthColor(for: i))
                                            .frame(height: 4)
                                    }
                                }
                                Text(strengthLabel)
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(strengthColor(for: 0))
                                    .frame(width: 48, alignment: .trailing)
                            }
                            .padding(.horizontal, 4)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("Password strength: \(strengthLabel)")
                        }

                        if showMismatch {
                            Text("Passwords don't match")
                                .font(.caption)
                                .foregroundColor(AuthTheme.destructive)
                                .padding(.horizontal, 4)
                        }
                    }

                    VStack(spacing: 12) {
                        if let error = viewModel.errorMessage {
                            AuthErrorBanner(message: error)
                        }

                        AuthPrimaryButton(title: "Create account", isLoading: viewModel.isLoading) {
                            hideKeyboard()
                            guard passwordsMatch else {
                                viewModel.errorMessage = "Passwords do not match"
                                return
                            }
                            Task { await viewModel.register() }
                        }

                        Text("By creating an account you agree to our [Terms of Service](https://invobilling.com/terms) and [Privacy Policy](https://invobilling.com/privacy).")
                            .font(.caption)
                            .foregroundColor(AuthTheme.muted)
                            .tint(AuthTheme.accent)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 8)
                    }

                    HStack(spacing: 4) {
                        Text("Already have an account?")
                            .foregroundColor(AuthTheme.muted)
                        Button {
                            presentationMode.wrappedValue.dismiss()
                        } label: {
                            Text("Sign in")
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
