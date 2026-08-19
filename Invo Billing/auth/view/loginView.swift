import SwiftUI

struct LoginView: View {
    @EnvironmentObject var viewModel: AuthViewModel
    
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            VStack(spacing: 0) {
                
                Spacer().frame(height: 80)
                
                VStack(spacing: 10) {
                    Text("WELCOME BACK")
                        .font(.system(size: 34, weight: .bold))
                        .tracking(0.8)
                        .foregroundColor(.black)
                    
                    Text("Sign in to continue")
                        .font(.system(size: 13))
                        .tracking(0.4)
                        .foregroundColor(.gray)
                }
                .padding(.bottom, 60)
                
                VStack(spacing: 28) {
                    LoginTextField(
                        label: "EMAIL",
                        placeholder: "you@example.com",
                        text: $viewModel.email,
                        keyboard: .emailAddress,
                        isSecure: false
                    )
                    
                    LoginTextField(
                        label: "PASSWORD",
                        placeholder: "••••••••",
                        text: $viewModel.password,
                        keyboard: .default,
                        isSecure: true
                    )
                    
                    // Forgot Password
                    HStack {
                        Spacer()
                        Button {
                            viewModel.resetEmail = viewModel.email
                            viewModel.showForgotPassword = true
                        } label: {
                            Text("FORGOT PASSWORD?")
                                .font(.system(size: 11))
                                .tracking(0.5)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    if let error = viewModel.errorMessage {
                        Text(error.uppercased())
                            .font(.system(size: 11))
                            .tracking(0.4)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    Button {
                        Task { await viewModel.login() }
                    } label: {
                        HStack {
                            if viewModel.isLoading {
                                ProgressView().tint(.black)
                            } else {
                                Text("SIGN IN")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.black)
                                    .tracking(0.8)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .overlay(Rectangle().stroke(Color.black, lineWidth: 1))
                    }
                    .disabled(viewModel.isLoading)
                    
                    // OTP Login
                    HStack {
                        Rectangle().frame(height: 0.5).foregroundColor(.black.opacity(0.1))
                        Text("OR")
                            .font(.system(size: 10, weight: .medium))
                            .tracking(0.8)
                            .foregroundColor(.gray)
                        Rectangle().frame(height: 0.5).foregroundColor(.black.opacity(0.1))
                    }
                    .padding(.vertical, 4)
                    
                    NavigationLink {
                        OTPLoginView().environmentObject(viewModel)
                    } label: {
                        Text("LOGIN WITH OTP")
                            .font(.system(size: 13, weight: .medium))
                            .tracking(0.8)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .overlay(
                                Rectangle()
                                    .stroke(Color.black.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
                .padding(.horizontal, 32)
                
                Spacer()
                
                HStack(spacing: 6) {
                    Text("DON'T HAVE AN ACCOUNT?")
                        .font(.system(size: 11))
                        .tracking(0.5)
                        .foregroundColor(.gray)
                    
                    NavigationLink {
                        SignupView()
                    } label: {
                        Text("SIGN UP")
                            .font(.system(size: 11, weight: .medium))
                            .tracking(0.8)
                            .foregroundColor(.black)
                    }
                }
                .padding(.bottom, 40)
            }
        }
    }
}


struct LoginTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    let keyboard: UIKeyboardType
    let isSecure: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .tracking(0.8)
                .foregroundColor(.gray)
            
            if isSecure {
                SecureField(placeholder, text: $text)
                    .keyboardType(keyboard)
                    .textInputAutocapitalization(.never)
                    .font(.system(size: 14))
                    .padding(.vertical, 12)
                    .overlay(
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(.black.opacity(0.25)),
                        alignment: .bottom
                    )
            } else {
                TextField(placeholder, text: $text)
                    .keyboardType(keyboard)
                    .textInputAutocapitalization(.never)
                    .font(.system(size: 14))
                    .padding(.vertical, 12)
                    .overlay(
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(.black.opacity(0.25)),
                        alignment: .bottom
                    )
            }
        }
    }
}
