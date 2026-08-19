//
//  ForgotPasswordView.swift
//  Invo Billing
//
//  Created by dharmaseervi on 4/20/26.
//


import SwiftUI

struct ForgotPasswordView: View {
    @EnvironmentObject var viewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 70)

                VStack(spacing: 10) {
                    Text(viewModel.resetCodeSent ? "CHECK YOUR EMAIL" : "FORGOT PASSWORD")
                        .font(.system(size: 34, weight: .bold))
                        .tracking(0.8)
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)

                    Text(viewModel.resetCodeSent
                         ? "Enter the code sent to\n\(viewModel.resetEmail)"
                         : "Enter your email to receive a reset code"
                    )
                    .font(.system(size: 13))
                    .tracking(0.4)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                }
                .padding(.bottom, 60)

                VStack(spacing: 28) {
                    if !viewModel.resetCodeSent {
                        EditorialInputField(
                            label: "EMAIL",
                            placeholder: "you@example.com",
                            text: $viewModel.resetEmail,
                            keyboard: .emailAddress,
                            isSecure: false
                        )
                    } else {
                        EditorialInputField(
                            label: "RESET CODE",
                            placeholder: "000000",
                            text: $viewModel.resetCode,
                            keyboard: .numberPad,
                            isSecure: false
                        )

                        EditorialInputField(
                            label: "NEW PASSWORD",
                            placeholder: "••••••••",
                            text: $viewModel.resetNewPassword,
                            keyboard: .default,
                            isSecure: true
                        )

                        EditorialInputField(
                            label: "CONFIRM PASSWORD",
                            placeholder: "••••••••",
                            text: $viewModel.resetConfirmPassword,
                            keyboard: .default,
                            isSecure: true
                        )
                    }

                    if let error = viewModel.errorMessage {
                        Text(error.uppercased())
                            .font(.system(size: 11))
                            .tracking(0.4)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
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
                                ProgressView().tint(.black)
                            } else {
                                Text(viewModel.resetCodeSent ? "RESET PASSWORD" : "SEND CODE")
                                    .font(.system(size: 13, weight: .medium))
                                    .tracking(0.8)
                                    .foregroundColor(.black)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .overlay(Rectangle().stroke(Color.black, lineWidth: 1))
                    }
                    .disabled(viewModel.isLoading)

                    if viewModel.resetCodeSent {
                        Button {
                            viewModel.resetCodeSent = false
                            viewModel.resetCode = ""
                            viewModel.errorMessage = nil
                        } label: {
                            Text("RESEND CODE")
                                .font(.system(size: 11))
                                .tracking(0.5)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.horizontal, 32)

                Spacer()

                Button { dismiss() } label: {
                    Text("BACK TO LOGIN")
                        .font(.system(size: 11))
                        .tracking(0.5)
                        .foregroundColor(.gray)
                }
                .padding(.bottom, 40)
            }
        }
        .navigationBarHidden(true)
    }
}