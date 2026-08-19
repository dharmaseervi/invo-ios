//
//  EmailVerificationView.swift
//  Invo Billing
//
//  Created by dharmaseervi on 4/15/26.
//


import SwiftUI

struct EmailVerificationView: View {
    @EnvironmentObject var viewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 70)

                VStack(spacing: 10) {
                    Text("VERIFY EMAIL")
                        .font(.system(size: 34, weight: .bold))
                        .tracking(0.8)
                        .foregroundColor(.black)

                    Text("Enter the 6-digit code sent to\n\(viewModel.verificationEmail)")
                        .font(.system(size: 13))
                        .tracking(0.4)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, 60)

                VStack(spacing: 28) {
                    // OTP input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("VERIFICATION CODE")
                            .font(.system(size: 10, weight: .medium))
                            .tracking(0.8)
                            .foregroundColor(.gray)

                        TextField("000000", text: $viewModel.verificationCode)
                            .keyboardType(.numberPad)
                            .font(.system(size: 32, weight: .bold))
                            .tracking(12)
                            .multilineTextAlignment(.center)
                            .onChange(of: viewModel.verificationCode) { val in
                                if val.count > 6 {
                                    viewModel.verificationCode = String(val.prefix(6))
                                }
                            }
                            .overlay(
                                Rectangle()
                                    .frame(height: 1)
                                    .foregroundColor(.black.opacity(0.25)),
                                alignment: .bottom
                            )
                    }

                    if let error = viewModel.errorMessage {
                        Text(error.uppercased())
                            .font(.system(size: 11))
                            .tracking(0.4)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Verify button
                    Button {
                        Task { await viewModel.verifyEmail() }
                    } label: {
                        HStack {
                            if viewModel.isLoading {
                                ProgressView().tint(.black)
                            } else {
                                Text("VERIFY ACCOUNT")
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

                    // Resend
                    Button {
                        Task {
                            try? await AuthService.shared.resendVerification(
                                email: viewModel.verificationEmail
                            )
                        }
                    } label: {
                        Text("RESEND CODE")
                            .font(.system(size: 11, weight: .medium))
                            .tracking(0.8)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 32)

                Spacer()
            }
        }
        .navigationBarHidden(true)
    }
}
