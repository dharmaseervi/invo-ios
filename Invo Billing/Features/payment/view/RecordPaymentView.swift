import SwiftUI

struct RecordPaymentView: View {

    @StateObject private var vm: RecordPaymentViewModel

    // MARK: - Init (make accessible)
    init(vm: RecordPaymentViewModel) {
        _vm = StateObject(wrappedValue: vm)
    }

    @Environment(\.dismiss) private var dismiss
    @FocusState private var amountFocused: Bool

    var body: some View {
        ZStack {
            Color.sBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                form
                saveButton
            }
        }
        .navigationTitle("Record payment")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task { await vm.loadUnpaidInvoices() }
        }
        .alert("Error", isPresented: $vm.showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }

    // MARK: - Form
    private var form: some View {
        ScrollView {
            VStack(spacing: 20) {
                contextCard
                amountSection
                if let due = vm.dueAmount, due > 0 {
                    quickAmountRow(due: due)
                }
                methodSection
                referenceSection

                if !vm.isInvoiceMode {
                    invoiceListSection
                }
            }
            .padding(AppSpacing.card)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Context Card
    private var contextCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.sAccentMuted)
                    .frame(width: 42, height: 42)
                Text(initials(for: vm.clientName))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.sAccent)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(vm.clientName.isEmpty ? "Client" : vm.clientName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.sForeground)
                Text(vm.invoiceNumber ?? "Applies to outstanding invoices")
                    .font(.footnote)
                    .foregroundStyle(Color.sMutedFG)
            }

            Spacer()

            if let due = vm.dueAmount {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(Money.text(due)).moneyLine()
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.sForeground)
                    Text("Due")
                        .font(.caption)
                        .foregroundStyle(Color.sMutedFG)
                }
            }
        }
        .padding(14)
        .background(Color.sCard)
        .overlay { RoundedRectangle(cornerRadius: 12).stroke(Color.sBorder, lineWidth: 0.5) }
        .clipShape(.rect(cornerRadius: 12))
    }

    private func initials(for name: String) -> String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    private var amountSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Amount")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.sMutedFG)

            HStack(spacing: 6) {
                Text("₹")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.sMutedFG)
                TextField("0.00", text: $vm.amount)
                    .keyboardType(.decimalPad)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.sForeground)
                    .tint(Color.sAccent)
                    .focused($amountFocused)
            }

            Rectangle().fill(amountFocused ? Color.sAccent : Color.sBorder).frame(height: 1)
        }
    }

    private func quickAmountRow(due: Double) -> some View {
        HStack(spacing: 8) {
            quickAmountChip(label: "25%", amount: due * 0.25)
            quickAmountChip(label: "50%", amount: due * 0.5)
            quickAmountChip(label: "Full amount", amount: due)
        }
    }

    private func quickAmountChip(label: String, amount: Double) -> some View {
        let isSelected = Double(vm.amount) == amount
        return Button {
            vm.amount = Money.editable(amount)
        } label: {
            Text(label)
                .font(.footnote.weight(.medium))
                .foregroundStyle(isSelected ? Color.sAccentFG : Color.sForeground)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(isSelected ? Color.sAccent : Color.sCard)
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.clear : Color.sBorder, lineWidth: 0.5)
                }
                .clipShape(.rect(cornerRadius: 8))
        }
    }

    private var methodSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Payment method")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.sMutedFG)

            HStack(spacing: 8) {
                ForEach(PaymentMethods.allCases, id: \.self) { m in
                    methodChip(m)
                }
            }
        }
    }

    private func methodChip(_ method: PaymentMethods) -> some View {
        let isSelected = vm.method == method
        return Button {
            vm.method = method
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon(for: method))
                    .font(.subheadline.weight(.medium))
                Text(label(for: method))
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(isSelected ? Color.sAccentFG : Color.sForeground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? Color.sAccent : Color.sCard)
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.clear : Color.sBorder, lineWidth: 0.5)
            }
            .clipShape(.rect(cornerRadius: 10))
        }
    }

    private func icon(for method: PaymentMethods) -> String {
        switch method {
        case .cash: return "banknote"
        case .upi: return "qrcode"
        case .bankTransfer: return "building.columns"
        case .cheque: return "doc.text"
        }
    }

    private func label(for method: PaymentMethods) -> String {
        switch method {
        case .cash: return "Cash"
        case .upi: return "UPI"
        case .bankTransfer: return "Bank"
        case .cheque: return "Cheque"
        }
    }

    private var referenceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Reference (optional)")
                    .font(.footnote)
                    .foregroundStyle(Color.sMutedFG)
                TextField("Transaction ID, cheque no...", text: $vm.reference)
                    .font(.body)
                    .foregroundStyle(Color.sForeground)
                    .tint(Color.sAccent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.sCard)
                    .overlay { RoundedRectangle(cornerRadius: 8).stroke(Color.sBorder, lineWidth: 0.5) }
                    .clipShape(.rect(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Notes (optional)")
                    .font(.footnote)
                    .foregroundStyle(Color.sMutedFG)
                TextField("Add a note", text: $vm.notes)
                    .font(.body)
                    .foregroundStyle(Color.sForeground)
                    .tint(Color.sAccent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.sCard)
                    .overlay { RoundedRectangle(cornerRadius: 8).stroke(Color.sBorder, lineWidth: 0.5) }
                    .clipShape(.rect(cornerRadius: 8))
            }
        }
    }

    private var invoiceListSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Applied to invoices")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.sMutedFG)

            VStack(spacing: 0) {
                ForEach(Array(vm.unpaidInvoices.enumerated()), id: \.element.id) { idx, invoice in
                    HStack {
                        Text(invoice.invoiceNumber)
                            .font(.subheadline)
                            .foregroundStyle(Color.sForeground)
                        Spacer()
                        Text(Money.text(invoice.remainingAmount)).moneyLine()
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.sForeground)
                    }
                    .padding(.vertical, 10)

                    if idx < vm.unpaidInvoices.count - 1 {
                        Rectangle().fill(Color.sBorder).frame(height: 0.5)
                    }
                }
            }
            .padding(14)
            .background(Color.sCard)
            .overlay { RoundedRectangle(cornerRadius: 10).stroke(Color.sBorder, lineWidth: 0.5) }
            .clipShape(.rect(cornerRadius: 10))
        }
    }

    // MARK: - Save Button
    private var saveButton: some View {
        Button {
            Task {
                if await vm.submitPayment() {
                    dismiss()
                }
            }
        } label: {
            HStack(spacing: 8) {
                if vm.isLoading {
                    ProgressView()
                        .tint(Color.sAccentFG)
                        .scaleEffect(0.85)
                } else {
                    Text("Save payment")
                        .font(.subheadline.weight(.semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(vm.isValid ? Color.sPrimary : Color.sPrimary.opacity(0.4))
            .foregroundStyle(Color.sAccentFG)
            .clipShape(.rect(cornerRadius: 10))
        }
        .disabled(!vm.isValid || vm.isLoading)
        .padding(AppSpacing.card)
        .padding(.bottom, 30)
    }
}
