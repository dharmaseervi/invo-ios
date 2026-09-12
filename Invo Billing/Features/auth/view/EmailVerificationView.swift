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
                            Image(systemName: "envelope.badge.fill")
                                .font(.scaled(20, weight: .medium))
                                .foregroundColor(.sAccentFG)
                        }
                        VStack(spacing: 4) {
                            Text("Verify your email")
                                .font(.scaled(20, weight: .semibold))
                                .foregroundColor(.sForeground)
                            Text("Enter the 6-digit code sent to\n\(viewModel.verificationEmail)")
                                .font(.scaled(13))
                                .foregroundColor(.sMutedFG)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.bottom, 32)

                    // MARK: - Card
                    VStack(spacing: 16) {

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Verification code")
                                .font(.scaled(13, weight: .medium))
                                .foregroundColor(.sForeground)

                            TextField("000000", text: $viewModel.verificationCode)
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
                                .onChange(of: viewModel.verificationCode) { newValue in
                                    if newValue.count > 6 {
                                        viewModel.verificationCode = String(newValue.prefix(6))
                                    }
                                }

                            // Progress dots
                            HStack(spacing: 8) {
                                ForEach(0..<6, id: \.self) { i in
                                    Circle()
                                        .fill(i < viewModel.verificationCode.count
                                              ? Color.sAccent
                                              : Color.sBorder)
                                        .frame(width: 8, height: 8)
                                        .animation(.spring(response: 0.2), value: viewModel.verificationCode.count)
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

                        // Verify button
                        Button {
                            Task { await viewModel.verifyEmail() }
                        } label: {
                            HStack {
                                if viewModel.isLoading {
                                    ProgressView()
                                        .tint(.sAccentFG)
                                        .scaleEffect(0.85)
                                } else {
                                    Text("Verify account")
                                        .font(.scaled(15, weight: .semibold))
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
                        Button {
                            Task { await viewModel.resendVerification() }
                        } label: {
                            Text("Resend code")
                                .font(.scaled(13, weight: .medium))
                                .foregroundColor(.sAccent)
                        }
                        .disabled(viewModel.isLoading)
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
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationBarHidden(true)
        .onTapGesture { hideKeyboard() }
    }
}
