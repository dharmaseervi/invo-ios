import SwiftUI

struct OTPLoginView: View {
    @EnvironmentObject var viewModel: AuthViewModel
    @Environment(\.presentationMode) var presentationMode
    
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
                            Image(systemName: viewModel.otpSent ? "envelope.badge.fill" : "iphone")
                                .font(.scaled(20, weight: .medium))
                                .foregroundColor(.sAccentFG)
                        }
                        
                        VStack(spacing: 4) {
                            Text(viewModel.otpSent ? "Check your email" : "Login with OTP")
                                .font(.scaled(20, weight: .semibold))
                                .foregroundColor(.sForeground)
                            
                            Text(viewModel.otpSent
                                 ? "Enter the 6-digit code sent to\n\(viewModel.otpEmail)"
                                 : "We'll send a login code to your email"
                            )
                            .font(.scaled(13))
                            .foregroundColor(.sMutedFG)
                            .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.bottom, 32)
                    
                    // MARK: - Card
                    VStack(spacing: 16) {
                        
                        if !viewModel.otpSent {
                            // Email field
                            VioletField(
                                label: "Email address",
                                placeholder: "name@company.com",
                                text: $viewModel.otpEmail,
                                keyboard: .emailAddress,
                                isSecure: false
                            )
                        } else {
                            // OTP code input
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Verification code")
                                    .font(.scaled(13, weight: .medium))
                                    .foregroundColor(.sForeground)
                                
                                TextField("000000", text: $viewModel.otpCode)
                                    .keyboardType(.numberPad)
                                    .font(.scaled(28, weight: .bold))
                                    .tracking(14)
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.sForeground)
                                    .tint(.sAccent)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color.sCard)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.sAccent.opacity(0.4), lineWidth: 1)
                                    )
                                    .cornerRadius(8)
                                    .onChange(of: viewModel.otpCode) { newValue in
                                        if newValue.count > 6 {
                                            viewModel.otpCode = String(newValue.prefix(6))
                                        }
                                    }
                                
                                // Progress dots
                                HStack(spacing: 8) {
                                    ForEach(0..<6, id: \.self) { i in
                                        Circle()
                                            .fill(i < viewModel.otpCode.count
                                                  ? Color.sAccent
                                                  : Color.sBorder)
                                            .frame(width: 8, height: 8)
                                            .animation(.spring(response: 0.2), value: viewModel.otpCode.count)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.top, 4)
                            }
                            
                            // Info banner
                            HStack(spacing: 8) {
                                Image(systemName: "clock")
                                    .font(.scaled(13))
                                    .foregroundColor(.sMutedFG)
                                Text("Code expires in 10 minutes")
                                    .font(.scaled(13))
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
                                    .font(.scaled(13))
                                    .foregroundColor(.sDestructive)
                                Text(error)
                                    .font(.scaled(13))
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
                            Task {
                                if viewModel.otpSent {
                                    await viewModel.verifyOTP()
                                } else {
                                    await viewModel.sendOTP()
                                }
                            }
                        } label: {
                            HStack {
                                if viewModel.isLoading {
                                    ProgressView()
                                        .tint(.sAccentFG)
                                        .scaleEffect(0.85)
                                } else {
                                    Text(viewModel.otpSent ? "Verify code" : "Send code")
                                        .font(.scaled(15, weight: .semibold))
                                        .foregroundColor(.sAccentFG)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                viewModel.isLoading
                                ? Color.sPrimary.opacity(0.6)
                                : Color.sPrimary
                            )
                            .cornerRadius(8)
                        }
                        .disabled(viewModel.isLoading)
                        
                        // Resend / Change email
                        if viewModel.otpSent {
                            HStack(spacing: 16) {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        viewModel.otpSent = false
                                        viewModel.otpCode = ""
                                        viewModel.errorMessage = nil
                                    }
                                } label: {
                                    Text("Change email")
                                        .font(.scaled(13))
                                        .foregroundColor(.sMutedFG)
                                }
                                
                                Rectangle()
                                    .fill(Color.sBorder)
                                    .frame(width: 0.5, height: 14)
                                
                                Button {
                                    Task { await viewModel.sendOTP() }
                                } label: {
                                    Text("Resend code")
                                        .font(.scaled(13, weight: .medium))
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
                        viewModel.otpSent = false
                        viewModel.otpCode = ""
                        viewModel.otpEmail = ""
                        viewModel.errorMessage = nil
                        presentationMode.wrappedValue.dismiss()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.scaled(12, weight: .semibold))
                            Text("Back to login")
                                .font(.scaled(13))
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
