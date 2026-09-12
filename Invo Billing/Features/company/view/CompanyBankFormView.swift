import SwiftUI

struct CompanyBankFormView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var vm: CompanyBankViewModel

    let companyId: Int
    var bank: CompanyBankResponse?

    // MARK: - State
    @State private var holder = ""
    @State private var bankName = ""
    @State private var account = ""
    @State private var ifsc = ""
    @State private var branch = ""
    @State private var upi = ""
    @State private var isDefault = false
    @State private var showError = false

    var isEditing: Bool { bank != nil }

    var body: some View {
        NavigationStack {
        ZStack {
            Color.sBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {

                        // Section: Account Holder
                        VStack(alignment: .leading, spacing: 14) {
                            sectionLabel("Account holder")
                            ZaraTextField(label: "Full name", text: $holder, placeholder: "e.g. John Doe")
                        }
                        .padding(.top, 20)

                        // Section: Bank Details
                        VStack(alignment: .leading, spacing: 14) {
                            sectionLabel("Bank details")

                            ZaraTextField(label: "Bank name", text: $bankName, placeholder: "e.g. HDFC Bank")

                            ZaraTextField(label: "Account number", text: $account, placeholder: "0000 0000 0000", keyboard: .numberPad)

                            HStack(spacing: 14) {
                                ZaraTextField(label: "IFSC code", text: $ifsc, placeholder: "HDFC0001234")
                                ZaraTextField(label: "Branch", text: $branch, placeholder: "Downtown")
                            }

                            ZaraTextField(label: "UPI ID (optional)", text: $upi, placeholder: "name@okaxis")
                        }

                        // Section: Settings
                        VStack(alignment: .leading, spacing: 12) {
                            sectionLabel("Preferences")

                            Toggle(isOn: $isDefault) {
                                Text("Set as default account")
                                    .font(.scaled(13))
                                    .foregroundColor(.sForeground)
                            }
                            .tint(.sAccent)
                        }

                        if showError {
                            Text("Please fill in all required fields.")
                                .font(.scaled(12))
                                .foregroundColor(.sDestructive)
                        }

                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                }

                actionButton
            }
        }
        .navigationTitle(isEditing ? "Edit bank" : "Add bank")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
        .onAppear {
            if let bank = bank {
                holder = bank.account_holder_name
                bankName = bank.bank_name
                account = bank.account_number
                ifsc = bank.ifsc_code
                branch = bank.branch ?? ""
                upi = bank.upi_id ?? ""
                isDefault = bank.is_default
            }
        }
        }
    }
}

// MARK: - Subviews
extension CompanyBankFormView {

    private var actionButton: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color.sBorder).frame(height: 0.5)
            Button(action: {
                Task { await handleSave() }
            }) {
                ZStack {
                    Color.sPrimary
                    if vm.isLoading {
                        ProgressView().tint(.sAccentFG)
                    } else {
                        Text(isEditing ? "Update account" : "Save bank details")
                            .font(.scaled(15, weight: .semibold))
                            .foregroundColor(.sAccentFG)
                    }
                }
                .frame(height: 60)
            }
            .disabled(vm.isLoading)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.scaled(13, weight: .medium))
            .foregroundColor(.sMutedFG)
    }

    private func handleSave() async {
        guard !holder.isEmpty, !bankName.isEmpty, !account.isEmpty else {
            showError = true
            return
        }

        let dto = CompanyBankRequestDTO(
            bank_name: bankName,
            company_id: companyId,
            account_holder_name: holder,
            account_number: account,
            ifsc_code: ifsc,
            upi_id: upi.isEmpty ? nil : upi,
            branch: branch.isEmpty ? nil : branch,
            is_default: isDefault
        )

        let success: Bool
        if isEditing, let bank = bank {
            success = await vm.updateBank(companyId: companyId, bankId: bank.id, dto: dto)
        } else {
            success = await vm.createBank(companyId: companyId, dto: dto)
        }

        if success {
            dismiss()
        }
    }
}

// MARK: - Custom Reusable Components

struct ZaraTextField: View {
    let label: String
    @Binding var text: String
    var placeholder: String
    var keyboard: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.scaled(11, weight: .medium))
                .foregroundColor(.sMutedFG)

            TextField("", text: $text, prompt: Text(placeholder).foregroundColor(.sMutedFG))
                .font(.scaled(15))
                .foregroundColor(.sForeground)
                .tint(.sAccent)
                .keyboardType(keyboard)
                .autocorrectionDisabled()

            Rectangle()
                .frame(height: 1)
                .foregroundColor(.sBorder)
        }
    }
}
