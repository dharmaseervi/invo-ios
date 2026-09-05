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
    
    var body: some View {
        ZStack {
            Color.sBackground.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer().frame(height: 52)
                    
                    // MARK: - Logo
                    VStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.sAccent)
                                .frame(width: 44, height: 44)
                            Image(systemName: viewModel.resetCodeSent
                                  ? "lock.rotation"
                                  : "key.fill")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.sAccentFG)
                        }
                        
                        VStack(spacing: 4) {
                            Text(viewModel.resetCodeSent
                                 ? "Reset your password"
                                 : "Forgot password")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.sForeground)
                            
                            Text(viewModel.resetCodeSent
                                 ? "Enter the code sent to\n\(viewModel.resetEmail)"
                                 : "Enter your email to receive a reset code")
                            .font(.system(size: 13))
                            .foregroundColor(.sMutedFG)
                            .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.bottom, 32)
                    
                    // MARK: - Card
                    VStack(spacing: 14) {
                        
                        if !viewModel.resetCodeSent {
                            
                            // Email field
                            VioletField(
                                label: "Email address",
                                placeholder: "name@company.com",
                                text: $viewModel.resetEmail,
                                keyboard: .emailAddress,
                                isSecure: false
                            )
                            
                        } else {
                            
                            // Reset code
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Reset code")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.sForeground)
                                
                                TextField("000000", text: $viewModel.resetCode)
                                    .keyboardType(.numberPad)
                                    .font(.system(size: 28, weight: .bold))
                                    .tracking(14)
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.sForeground)
                                    .tint(.sAccent)
                                    .padding(.vertical, 14)
                                    .background(Color.sCard)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.sAccent.opacity(0.4), lineWidth: 1)
                                    )
                                    .cornerRadius(8)
                                    .onChange(of: viewModel.resetCode) { newValue in
                                        if newValue.count > 6 {
                                            viewModel.resetCode = String(newValue.prefix(6))
                                        }
                                    }
                                
                                // Progress dots
                                HStack(spacing: 8) {
                                    ForEach(0..<6, id: \.self) { i in
                                        Circle()
                                            .fill(i < viewModel.resetCode.count
                                                  ? Color.sAccent
                                                  : Color.sBorder)
                                            .frame(width: 8, height: 8)
                                            .animation(.spring(response: 0.2), value: viewModel.resetCode.count)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.top, 4)
                            }
                            
                            // New password
                            VStack(alignment: .leading, spacing: 6) {
                                Text("New password")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.sForeground)
                                
                                HStack(spacing: 10) {
                                    Group {
                                        if showPassword {
                                            TextField("Create new password", text: $viewModel.resetNewPassword)
                                        } else {
                                            SecureField("Create new password", text: $viewModel.resetNewPassword)
                                        }
                                    }
                                    .font(.system(size: 14))
                                    .foregroundColor(.sForeground)
                                    .tint(.sAccent)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    
                                    Button {
                                        showPassword.toggle()
                                    } label: {
                                        Image(systemName: showPassword ? "eye.slash" : "eye")
                                            .font(.system(size: 14))
                                            .foregroundColor(.sMutedFG)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Color.sCard)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.sInput, lineWidth: 0.5)
                                )
                                .cornerRadius(8)
                            }
                            
                            // Confirm password
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Confirm password")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.sForeground)
                                
                                HStack(spacing: 10) {
                                    Group {
                                        if showConfirm {
                                            TextField("Repeat new password", text: $viewModel.resetConfirmPassword)
                                        } else {
                                            SecureField("Repeat new password", text: $viewModel.resetConfirmPassword)
                                        }
                                    }
                                    .font(.system(size: 14))
                                    .foregroundColor(.sForeground)
                                    .tint(.sAccent)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    
                                    if !viewModel.resetConfirmPassword.isEmpty {
                                        Image(systemName: passwordsMatch
                                              ? "checkmark.circle.fill"
                                              : "xmark.circle.fill")
                                        .font(.system(size: 15))
                                        .foregroundColor(passwordsMatch
                                                         ? Color(red: 0.086, green: 0.639, blue: 0.341)
                                                         : .sDestructive)
                                    } else {
                                        Button {
                                            showConfirm.toggle()
                                        } label: {
                                            Image(systemName: showConfirm ? "eye.slash" : "eye")
                                                .font(.system(size: 14))
                                                .foregroundColor(.sMutedFG)
                                        }
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Color.sCard)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(
                                            !viewModel.resetConfirmPassword.isEmpty && !passwordsMatch
                                            ? Color.sDestructive.opacity(0.5)
                                            : Color.sInput,
                                            lineWidth: 0.5
                                        )
                                )
                                .cornerRadius(8)
                            }
                            
                            // Info banner
                            HStack(spacing: 8) {
                                Image(systemName: "clock")
                                    .font(.system(size: 13))
                                    .foregroundColor(.sMutedFG)
                                Text("Code expires in 10 minutes")
                                    .font(.system(size: 13))
                                    .foregroundColor(.sMutedFG)
                                Spacer()
                            }
                            .padding(12)
                            .background(Color.sMuted)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.sBorder, lineWidth: 0.5)
                            )
                            .cornerRadius(8)
                        }
                        
                        // Error
                        if let error = viewModel.errorMessage {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.circle")
                                    .font(.system(size: 13))
                                    .foregroundColor(.sDestructive)
                                Text(error)
                                    .font(.system(size: 13))
                                    .foregroundColor(.sDestructive)
                                Spacer()
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.sDestructive.opacity(0.06))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.sDestructive.opacity(0.2), lineWidth: 0.5)
                                    )
                            )
                        }
                        
                        // Action button
                        Button {
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
                        } label: {
                            HStack {
                                if viewModel.isLoading {
                                    ProgressView()
                                        .tint(.sAccentFG)
                                        .scaleEffect(0.85)
                                } else {
                                    Text(viewModel.resetCodeSent
                                         ? "Reset password"
                                         : "Send code")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.sAccentFG)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.sPrimary)
                            .cornerRadius(8)
                        }
                        .disabled(viewModel.isLoading)
                        
                        // Resend
                        if viewModel.resetCodeSent {
                            HStack(spacing: 16) {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        viewModel.resetCodeSent = false
                                        viewModel.resetCode = ""
                                        viewModel.errorMessage = nil
                                    }
                                } label: {
                                    Text("Change email")
                                        .font(.system(size: 13))
                                        .foregroundColor(.sMutedFG)
                                }
                                
                                Rectangle()
                                    .fill(Color.sBorder)
                                    .frame(width: 0.5, height: 14)
                                
                                Button {
                                    Task { await viewModel.forgotPassword() }
                                } label: {
                                    Text("Resend code")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.sAccent)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(20)
                    .background(Color.sCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.sBorder, lineWidth: 0.5)
                    )
                    .cornerRadius(12)
                    .shadow(
                        color: Color(UIColor.label).opacity(0.06),
                        radius: 20, x: 0, y: 8
                    )
                    .padding(.horizontal, 24)
                    
                    // Back to login
                    Button {
                        viewModel.resetCodeSent = false
                        viewModel.resetCode = ""
                        viewModel.errorMessage = nil
                        presentationMode.wrappedValue.dismiss()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Back to login")
                                .font(.system(size: 13))
                        }
                        .foregroundColor(.sMutedFG)
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
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
