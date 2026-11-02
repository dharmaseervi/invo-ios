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
                                .font(.subheadline)
                                .foregroundStyle(Color.sMutedFG)
                            Text(isReminder
                                 ? "A payment reminder with the invoice PDF attached will be sent"
                                 : "The invoice PDF will be attached automatically")
                                .font(.subheadline)
                                .foregroundStyle(Color.sMutedFG)
                            Spacer()
                        }
                        .padding(12)
                        .background(Color.sMuted)
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.sBorder, lineWidth: 0.5)
                        }
                        .clipShape(.rect(cornerRadius: 8))
                        
                        // Name field
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Recipient name")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color.sForeground)
                            
                            TextField("John Doe", text: $toName)
                                .font(.body)
                                .foregroundStyle(Color.sForeground)
                                .tint(Color.sAccent)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Color.sCard)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.sInput, lineWidth: 0.5)
                                }
                                .clipShape(.rect(cornerRadius: 8))
                        }
                        
                        // Email field
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Email address")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color.sForeground)
                            
                            HStack {
                                TextField("client@example.com", text: $toEmail)
                                    .font(.body)
                                    .foregroundStyle(Color.sForeground)
                                    .keyboardType(.emailAddress)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .tint(Color.sAccent)
                                
                                if !toEmail.isEmpty {
                                    Image(systemName: emailValid
                                          ? "checkmark.circle.fill"
                                          : "xmark.circle.fill")
                                    .font(.body)
                                    .foregroundStyle(emailValid
                                                     ? Color.sSuccess
                                                     : Color.sDestructive)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.sCard)
                            .overlay {
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.sInput, lineWidth: 0.5)
                            }
                            .clipShape(.rect(cornerRadius: 8))
                        }
                    }
                    .padding(.horizontal, AppSpacing.page)
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
                                        .tint(Color.sAccentFG)
                                        .scaleEffect(0.8)
                                    Text("Sending...")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(Color.sAccentFG)
                                } else {
                                    Image(systemName: "paperplane")
                                        .font(.subheadline)
                                        .foregroundStyle(Color.sAccentFG)
                                    Text(isReminder ? "Send reminder" : "Send invoice")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(Color.sAccentFG)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(isValid && !vm.isSendingEmail
                                        ? Color.sPrimary
                                        : Color.sMuted)
                            .clipShape(.rect(cornerRadius: 8))
                        }
                        .disabled(!isValid || vm.isSendingEmail)
                    }
                    .padding(.horizontal, AppSpacing.page)
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
