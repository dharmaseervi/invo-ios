import SwiftUI

struct SignupView: View {
    @EnvironmentObject var viewModel: AuthViewModel
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    
                    Spacer().frame(height: 70)
                    
                    // MARK: - Header (Editorial)
                    VStack(spacing: 10) {
                        Text("CREATE ACCOUNT")
                            .font(.system(size: 34, weight: .bold))
                            .tracking(0.8)
                            .foregroundColor(.black)
                        
                        Text("Join Invo to manage invoices smarter")
                            .font(.system(size: 13))
                            .tracking(0.4)
                            .foregroundColor(.gray)
                    }
                    .padding(.bottom, 60)
                    
                    // MARK: - Form
                    VStack(spacing: 28) {
                        
                        EditorialInputField(
                            label: "EMAIL",
                            placeholder: "you@example.com",
                            text: $viewModel.email,
                            keyboard: .emailAddress,
                            isSecure: false
                        )
                        
                        EditorialInputField(
                            label: "PASSWORD",
                            placeholder: "••••••••",
                            text: $viewModel.password,
                            keyboard: .default,
                            isSecure: true
                        )
                        
                        EditorialInputField(
                            label: "CONFIRM PASSWORD",
                            placeholder: "••••••••",
                            text: $viewModel.confirmPassword,
                            keyboard: .default,
                            isSecure: true
                        )
                        
                        // Error
                        if let error = viewModel.errorMessage {
                            Text(error.uppercased())
                                .font(.system(size: 11))
                                .tracking(0.4)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        
                        // MARK: - Create Account Button
                        Button {
                            Task {
                                if viewModel.password == viewModel.confirmPassword {
                                    await viewModel.register()
                                } else {
                                    viewModel.errorMessage = "Passwords do not match"
                                }
                            }
                        } label: {
                            HStack {
                                if viewModel.isLoading {
                                    ProgressView().tint(.black)
                                } else {
                                    Text("CREATE ACCOUNT")
                                        .font(.system(size: 13, weight: .medium))
                                        .tracking(0.8)
                                        .foregroundColor(.black)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .overlay(
                                Rectangle()
                                    .stroke(Color.black, lineWidth: 1)
                            )
                        }
                        .disabled(viewModel.isLoading)
                    }
                    .padding(.horizontal, 32)
                    
                    Spacer()
                    
                    // MARK: - Footer
                    HStack(spacing: 6) {
                        Text("ALREADY HAVE AN ACCOUNT?")
                            .font(.system(size: 11))
                            .tracking(0.5)
                            .foregroundColor(.gray)
                        
                        NavigationLink {
                            LoginView()
                        } label: {
                            Text("SIGN IN")
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
}


struct EditorialInputField: View {
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
            
            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .keyboardType(keyboard)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
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
