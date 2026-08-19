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
        ZStack {
            Color.white.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom Navigation Bar
                headerView
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 32) {
                        
                        // Section: Account Holder
                        VStack(alignment: .leading, spacing: 24) {
                            sectionLabel("ACCOUNT HOLDER")
                            ZaraTextField(label: "FULL NAME", text: $holder, placeholder: "e.g. John Doe")
                        }
                        .padding(.top, 20)
                        
                        // Section: Bank Details
                        VStack(alignment: .leading, spacing: 24) {
                            sectionLabel("BANK DETAILS")
                            
                            ZaraTextField(label: "BANK NAME", text: $bankName, placeholder: "e.g. HDFC Bank")
                            
                            ZaraTextField(label: "ACCOUNT NUMBER", text: $account, placeholder: "0000 0000 0000", keyboard: .numberPad)
                            
                            HStack(spacing: 20) {
                                ZaraTextField(label: "IFSC CODE", text: $ifsc, placeholder: "HDFC0001234")
                                ZaraTextField(label: "BRANCH", text: $branch, placeholder: "Downtown")
                            }
                            
                            ZaraTextField(label: "UPI ID (OPTIONAL)", text: $upi, placeholder: "name@okaxis")
                        }
                        
                        // Section: Settings
                        VStack(alignment: .leading, spacing: 16) {
                            sectionLabel("PREFERENCES")
                            
                            Toggle(isOn: $isDefault) {
                                Text("SET AS DEFAULT ACCOUNT")
                                    .font(.system(size: 12, weight: .light))
                                    .tracking(1)
                            }
                            .tint(.black)
                        }
                        
                        if showError {
                            Text("Please fill in all required fields.")
                                .font(.system(size: 10))
                                .foregroundColor(.red)
                                .tracking(0.5)
                        }
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 24)
                }
                
                // Fixed Bottom Action Button
                actionButton
            }
        }
        .navigationBarHidden(true)
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

// MARK: - Subviews
extension CompanyBankFormView {
    
    private var headerView: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .light))
                        .foregroundColor(.black)
                }
                
                Spacer()
                
                Text(isEditing ? "EDIT BANK" : "ADD NEW BANK")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(2)
                
                Spacer()
                
                // Empty view to balance the HStack
                Color.clear.frame(width: 16, height: 16)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            
            Divider().background(Color.black.opacity(0.1))
        }
    }
    
    private var actionButton: some View {
        VStack(spacing: 0) {
            Divider()
            Button(action: {
                Task { await handleSave() }
            }) {
                ZStack {
                    Color.black
                    if vm.isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text(isEditing ? "UPDATE ACCOUNT" : "SAVE BANK DETAILS")
                            .font(.system(size: 13, weight: .bold))
                            .tracking(1.5)
                            .padding(.vertical, 8)
                            .foregroundColor(.white)
                    }
                }
                .frame(height: 60)
            }
            .disabled(vm.isLoading)
        }
    }
    
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .tracking(1.5)
            .foregroundColor(.gray)
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
            dismiss() // Form closes on success
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
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(1)
                .foregroundColor(.black.opacity(0.6))
            
            TextField("", text: $text, prompt: Text(placeholder).font(.system(size: 14, weight: .light)).foregroundColor(.gray.opacity(0.5)))
                .font(.system(size: 16, weight: .regular))
                .keyboardType(keyboard)
                .autocorrectionDisabled()
            
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.black.opacity(0.1))
        }
    }
}
