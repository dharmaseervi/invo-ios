import SwiftUI

struct OTPLoginView: View {
    @EnvironmentObject var viewModel: AuthViewModel
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        ZStack {
            AuthBackdrop()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 32) {
                    AuthBackButton {
                        viewModel.otpSent = false
                        viewModel.otpCode = ""
                        viewModel.otpEmail = ""
                        viewModel.errorMessage = nil
                        presentationMode.wrappedValue.dismiss()
                    }

                    AuthHeader(
                        title: viewModel.otpSent ? "Check your email" : "Sign in with OTP",
                        subtitle: viewModel.otpSent
                            ? "Enter the 6-digit code sent to \(viewModel.otpEmail)"
                            : "We'll email you a one-time sign-in code",
                        symbol: viewModel.otpSent ? "envelope.badge" : "iphone"
                    )

                    if viewModel.otpSent {
                        VStack(alignment: .leading, spacing: 12) {
                            AuthCodeField(code: $viewModel.otpCode)
                            AuthHint(icon: "clock", text: "Code expires in 10 minutes")
                        }
                    } else {
                        AuthFieldGroup {
                            AuthInputRow(
                                icon: "envelope",
                                placeholder: "Email",
                                text: $viewModel.otpEmail,
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
                            title: viewModel.otpSent ? "Verify code" : "Send code",
                            isLoading: viewModel.isLoading
                        ) {
                            hideKeyboard()
                            Task {
                                if viewModel.otpSent {
                                    await viewModel.verifyOTP()
                                } else {
                                    await viewModel.sendOTP()
                                }
                            }
                        }

                        if viewModel.otpSent {
                            HStack(spacing: 24) {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        viewModel.otpSent = false
                                        viewModel.otpCode = ""
                                        viewModel.errorMessage = nil
                                    }
                                } label: {
                                    Text("Change email")
                                        .foregroundColor(AuthTheme.muted)
                                }

                                Button {
                                    Task { await viewModel.sendOTP() }
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
