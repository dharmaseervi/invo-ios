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
        case 2:    return Color(red: 0.851, green: 0.588, blue: 0.082)
        default:   return Color(red: 0.196, green: 0.769, blue: 0.478)
        }
    }

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
                            Text("Create account")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(AuthTheme.foreground)
                            Text("Start managing your invoices")
                                .font(.system(size: 13))
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

                        // Password
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundColor(AuthTheme.muted)

                            HStack(spacing: 10) {
                                Group {
                                    if showPassword {
                                        TextField("Create a password", text: $viewModel.password)
                                    } else {
                                        SecureField("Create a password", text: $viewModel.password)
                                    }
                                }
                                .font(.system(size: 14))
                                .foregroundColor(AuthTheme.foreground)
                                .tint(AuthTheme.accentBright)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()

                                Button {
                                    showPassword.toggle()
                                } label: {
                                    Image(systemName: showPassword ? "eye.slash" : "eye")
                                        .font(.system(size: 14))
                                        .foregroundColor(AuthTheme.muted)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(AuthTheme.field)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(AuthTheme.border, lineWidth: 1))
                            .cornerRadius(10)

                            if !viewModel.password.isEmpty {
                                HStack(spacing: 6) {
                                    ForEach(0..<4, id: \.self) { i in
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(strengthColor(for: i))
                                            .frame(height: 3)
                                    }
                                }
                                Text(strengthLabel)
                                    .font(.system(size: 11))
                                    .foregroundColor(strengthColor(for: 0))
                            }
                        }

                        // Confirm password
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Confirm password")
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundColor(AuthTheme.muted)

                            HStack(spacing: 10) {
                                Group {
                                    if showConfirm {
                                        TextField("Repeat your password", text: $viewModel.confirmPassword)
                                    } else {
                                        SecureField("Repeat your password", text: $viewModel.confirmPassword)
                                    }
                                }
                                .font(.system(size: 14))
                                .foregroundColor(AuthTheme.foreground)
                                .tint(AuthTheme.accentBright)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()

                                if !viewModel.confirmPassword.isEmpty {
                                    Image(systemName: passwordsMatch ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .font(.system(size: 15))
                                        .foregroundColor(passwordsMatch
                                                         ? Color(red: 0.196, green: 0.769, blue: 0.478)
                                                         : AuthTheme.destructive)
                                } else {
                                    Button {
                                        showConfirm.toggle()
                                    } label: {
                                        Image(systemName: showConfirm ? "eye.slash" : "eye")
                                            .font(.system(size: 14))
                                            .foregroundColor(AuthTheme.muted)
                                    }
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(AuthTheme.field)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(
                                        !viewModel.confirmPassword.isEmpty && !passwordsMatch
                                        ? AuthTheme.destructive.opacity(0.6)
                                        : AuthTheme.border,
                                        lineWidth: 1
                                    )
                            )
                            .cornerRadius(10)
                        }

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
                        .padding(.top, 4)

                        Text("By creating an account you agree to our [Terms of Service](https://invobilling.com/terms) and [Privacy Policy](https://invobilling.com/privacy).")
                            .font(.system(size: 11))
                            .foregroundColor(AuthTheme.muted)
                            .tint(AuthTheme.accent)
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)
                    }
                    .padding(.horizontal, 24)

                    // Sign in link
                    HStack(spacing: 4) {
                        Text("Already have an account?")
                            .font(.system(size: 13))
                            .foregroundColor(AuthTheme.muted)
                        Button {
                            presentationMode.wrappedValue.dismiss()
                        } label: {
                            Text("Sign in")
                                .font(.system(size: 13, weight: .semibold))
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
