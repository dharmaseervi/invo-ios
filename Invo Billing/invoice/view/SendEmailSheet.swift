//
//  SendEmailSheet.swift
//  Invo Billing
//
//  Created by dharmaseervi on 3/17/26.
//
import SwiftUI


struct SendEmailSheet: View {
    let invoiceID: Int
    let invoiceNumber: String
    let vm: InvoiceViewModel

    @State private var toEmail = ""
    @State private var toName = ""
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.zaraWhite.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 4) {
                        Text("SEND INVOICE")
                            .font(.system(size: 20, weight: .thin))
                            .tracking(6)
                            .foregroundColor(.zaraBlack)

                        Text(invoiceNumber)
                            .font(.system(size: 11, weight: .light))
                            .tracking(2)
                            .foregroundColor(.zaraGray)
                    }
                    .padding(.vertical, 32)

                    Rectangle()
                        .fill(Color.zaraLightGray)
                        .frame(height: 1)
                        .padding(.horizontal, 24)

                    VStack(spacing: 24) {
                        // Name Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("CLIENT NAME")
                                .font(.system(size: 10, weight: .regular))
                                .tracking(2)
                                .foregroundColor(.zaraGray)

                            TextField("e.g. John Doe", text: $toName)
                                .font(.system(size: 14, weight: .light))
                                .foregroundColor(.zaraBlack)
                                .padding(.vertical, 14)
                                .overlay(
                                    Rectangle()
                                        .fill(Color.zaraLightGray)
                                        .frame(height: 1),
                                    alignment: .bottom
                                )
                        }

                        // Email Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("CLIENT EMAIL")
                                .font(.system(size: 10, weight: .regular))
                                .tracking(2)
                                .foregroundColor(.zaraGray)

                            TextField("e.g. client@email.com", text: $toEmail)
                                .font(.system(size: 14, weight: .light))
                                .foregroundColor(.zaraBlack)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .padding(.vertical, 14)
                                .overlay(
                                    Rectangle()
                                        .fill(Color.zaraLightGray)
                                        .frame(height: 1),
                                    alignment: .bottom
                                )
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 32)

                    Spacer()

                    // Send Button
                    Button {
                        Task {
                            await vm.sendInvoiceEmail(
                                invoiceID: invoiceID,
                                toEmail: toEmail,
                                toName: toName
                            )
                            dismiss()
                        }
                    } label: {
                        HStack(spacing: 12) {
                            if vm.isSendingEmail {
                                ProgressView()
                                    .tint(.zaraWhite)
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "paperplane")
                                    .font(.system(size: 13, weight: .light))
                            }
                            Text(vm.isSendingEmail ? "SENDING..." : "SEND INVOICE")
                                .font(.system(size: 12, weight: .regular))
                                .tracking(3)
                        }
                        .foregroundColor(.zaraWhite)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            toEmail.isEmpty || toName.isEmpty
                                ? Color.zaraGray
                                : Color.zaraBlack
                        )
                    }
                    .disabled(toEmail.isEmpty || toName.isEmpty || vm.isSendingEmail)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("CANCEL") { dismiss() }
                        .font(.system(size: 11, weight: .light))
                        .tracking(2)
                        .foregroundColor(.zaraGray)
                }
            }
        }
    }
}
