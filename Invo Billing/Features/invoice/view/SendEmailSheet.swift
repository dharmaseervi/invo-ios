import SwiftUI

struct SendEmailSheet: View {
    let invoiceID: Int
    let invoiceNumber: String
    let vm: InvoiceViewModel
    let onDismiss: () -> Void
    var isReminder: Bool = false

    @State private var toEmail = ""
    @State private var toName = ""
    
    var isValid: Bool { !toEmail.isEmpty && !toName.isEmpty }
    var emailValid: Bool { toEmail.contains("@") && toEmail.contains(".") }
    
    var body: some View {
        NavigationStack {
        ZStack {
            Color.sBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        
                        // Info banner
                        HStack(spacing: 10) {
                            Image(systemName: "paperclip")
                                .font(.scaled(13))
                                .foregroundColor(.sMutedFG)
                            Text(isReminder
                                 ? "A payment reminder with the invoice PDF attached will be sent"
                                 : "The invoice PDF will be attached automatically")
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
                        
                        // Name field
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Recipient name")
                                .font(.scaled(13, weight: .medium))
                                .foregroundColor(.sForeground)
                            
                            TextField("John Doe", text: $toName)
                                .font(.scaled(14))
                                .foregroundColor(.sForeground)
                                .tint(.sAccent)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Color.sCard)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.sInput, lineWidth: 0.5)
                                )
                                .cornerRadius(8)
                        }
                        
                        // Email field
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Email address")
                                .font(.scaled(13, weight: .medium))
                                .foregroundColor(.sForeground)
                            
                            HStack {
                                TextField("client@example.com", text: $toEmail)
                                    .font(.scaled(14))
                                    .foregroundColor(.sForeground)
                                    .keyboardType(.emailAddress)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .tint(.sAccent)
                                
                                if !toEmail.isEmpty {
                                    Image(systemName: emailValid
                                          ? "checkmark.circle.fill"
                                          : "xmark.circle.fill")
                                    .font(.scaled(15))
                                    .foregroundColor(emailValid
                                                     ? Color(red: 0.086, green: 0.639, blue: 0.341)
                                                     : .sDestructive)
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
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 32)
                }
                
                Spacer()
                
                // Actions
                VStack(spacing: 8) {
                    Rectangle().fill(Color.sBorder).frame(height: 0.5)
                    
                    VStack(spacing: 8) {
                        // Send button
                        Button {
                            Task {
                                await vm.sendInvoiceEmail(
                                    invoiceID: invoiceID,
                                    toEmail: toEmail,
                                    toName: toName,
                                    isReminder: isReminder
                                )
                                onDismiss() // ← closure not @Environment
                            }
                        } label: {
                            HStack(spacing: 8) {
                                if vm.isSendingEmail {
                                    ProgressView()
                                        .tint(.sAccentFG)
                                        .scaleEffect(0.8)
                                    Text("Sending...")
                                        .font(.scaled(14, weight: .medium))
                                        .foregroundColor(.sAccentFG)
                                } else {
                                    Image(systemName: "paperplane")
                                        .font(.scaled(13))
                                        .foregroundColor(.sAccentFG)
                                    Text(isReminder ? "Send reminder" : "Send invoice")
                                        .font(.scaled(14, weight: .medium))
                                        .foregroundColor(.sAccentFG)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(isValid && !vm.isSendingEmail
                                        ? Color.sPrimary
                                        : Color.sMuted)
                            .cornerRadius(8)
                        }
                        .disabled(!isValid || vm.isSendingEmail)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
        }
        .onTapGesture { hideKeyboard() }
        .navigationTitle(isReminder ? "Remind \(invoiceNumber)" : "Send \(invoiceNumber)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { onDismiss() }
            }
        }
        }
    }
}
