//
//  OTPLoginView.swift
//  Invo Billing
//
//  Created by dharmaseervi on 4/15/26.
//


import SwiftUI

struct OTPLoginView: View {
    @EnvironmentObject var viewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 70)

                // MARK: - Header
                VStack(spacing: 10) {
                    Text(viewModel.otpSent ? "CHECK YOUR EMAIL" : "LOGIN WITH OTP")
                        .font(.system(size: 34, weight: .bold))
                        .tracking(0.8)
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)

                    Text(viewModel.otpSent
                         ? "Enter the 6-digit code sent to\n\(viewModel.otpEmail)"
                         : "We'll send a login code to your email"
                    )
                    .font(.system(size: 13))
                    .tracking(0.4)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                }
                .padding(.bottom, 60)

                // MARK: - Form
                VStack(spacing: 28) {
                    if !viewModel.otpSent {
                        // Email input
                        EditorialInputField(
                            label: "EMAIL",
                            placeholder: "you@example.com",
                            text: $viewModel.otpEmail,
                            keyboard: .emailAddress,
                            isSecure: false
                        )
                    } else {
                        // OTP input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("OTP CODE")
                                .font(.system(size: 10, weight: .medium))
                                .tracking(0.8)
                                .foregroundColor(.gray)

                            TextField("000000", text: $viewModel.otpCode)
                                .keyboardType(.numberPad)
                                .font(.system(size: 32, weight: .bold))
                                .tracking(12)
                                .multilineTextAlignment(.center)
                                .padding(.vertical, 12)
                                .onChange(of: viewModel.otpCode) { newValue in
                                    // Limit to 6 digits
                                    if newValue.count > 6 {
                                        viewModel.otpCode = String(newValue.prefix(6))
                                    }
                                }
                                .overlay(
                                    Rectangle()
                                        .frame(height: 1)
                                        .foregroundColor(.black.opacity(0.25)),
                                    alignment: .bottom
                                )
                        }
                    }

                    // Error
                    if let error = viewModel.errorMessage {
                        Text(error.uppercased())
                            .font(.system(size: 11))
                            .tracking(0.4)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Action button
                    Button {
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
                                ProgressView().tint(.black)
                            } else {
                                Text(viewModel.otpSent ? "VERIFY CODE" : "SEND CODE")
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

                    // Resend / Back
                    if viewModel.otpSent {
                        HStack(spacing: 6) {
                            Button {
                                viewModel.otpSent = false
                                viewModel.otpCode = ""
                                viewModel.errorMessage = nil
                            } label: {
                                Text("CHANGE EMAIL")
                                    .font(.system(size: 11))
                                    .tracking(0.5)
                                    .foregroundColor(.gray)
                            }

                            Text("·")
                                .foregroundColor(.gray)

                            Button {
                                Task { await viewModel.sendOTP() }
                            } label: {
                                Text("RESEND CODE")
                                    .font(.system(size: 11, weight: .medium))
                                    .tracking(0.8)
                                    .foregroundColor(.black)
                            }
                        }
                    }
                }
                .padding(.horizontal, 32)

                Spacer()

                // Footer
                Button {
                    viewModel.otpSent = false
                    viewModel.otpCode = ""
                    viewModel.otpEmail = ""
                    viewModel.errorMessage = nil
                    dismiss()
                } label: {
                    Text("BACK TO LOGIN")
                        .font(.system(size: 11))
                        .tracking(0.5)
                        .foregroundColor(.gray)
                }
                .padding(.bottom, 40)
            }
        }
    }
}