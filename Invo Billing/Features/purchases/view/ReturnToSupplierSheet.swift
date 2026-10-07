//
//  ReturnToSupplierSheet.swift
//  Invo Billing
//
//  Sending stock back to a supplier.
//

import SwiftUI

struct ReturnToSupplierSheet: View {
    let bill: PurchaseBill
    @ObservedObject var vm: PurchasesViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var detail: PurchaseBillDetail?
    @State private var returnNumber = ""
    @State private var reason = ""
    /// How many of each line are going back, keyed by item.
    @State private var sending: [Int: String] = [:]
    @State private var isLoading = true
    @State private var errorMessage: String?

    private var lines: [PurchaseBillLine] { detail?.items ?? [] }

    private var total: Double {
        lines.reduce(0) { sum, line in
            let qty = Double(sending[line.item_id] ?? "") ?? 0
            let net = qty * line.rate
            return sum + net + net * line.tax_rate / 100
        }
    }

    private var canSave: Bool {
        !returnNumber.trimmingCharacters(in: .whitespaces).isEmpty
            && total > 0
            && !overReturning
            && !vm.isWorking
    }

    /// Somebody has typed more than the bill contained. Caught here as well as on the
    /// server so the number turns red as it is typed rather than after saving.
    private var overReturning: Bool {
        lines.contains { line in
            (Int(sending[line.item_id] ?? "") ?? 0) > line.qty
        }
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("Bill", value: bill.bill_number)
                LabeledContent("Supplier", value: bill.supplier_name)
                TextField("Return number", text: $returnNumber)
                    .autocorrectionDisabled()
                TextField("Why (optional)", text: $reason)
            } footer: {
                Text("Give this return a number of your own — it is what you and the supplier will both refer to.")
            }

            Section {
                if isLoading {
                    HStack {
                        ProgressView().tint(.sAccent)
                        Text("Loading the bill…")
                            .font(.scaled(13))
                            .foregroundColor(.sMutedFG)
                    }
                } else {
                    ForEach(lines) { line in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(line.item_name)
                                .font(.scaled(14, weight: .medium))
                            HStack {
                                Text("\(line.qty) came in at \(Money.text(line.rate))")
                                    .font(.scaled(12))
                                    .foregroundColor(.sMutedFG)
                                Spacer()
                                TextField("0", text: Binding(
                                    get: { sending[line.item_id] ?? "" },
                                    set: { sending[line.item_id] = $0 }
                                ))
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 60)
                            }
                            if (Int(sending[line.item_id] ?? "") ?? 0) > line.qty {
                                Text("Only \(line.qty) came in on this bill.")
                                    .font(.scaled(12))
                                    .foregroundColor(.sDestructive)
                            }
                        }
                    }
                }
            } header: {
                Text("How many are going back")
            } footer: {
                if total > 0 {
                    // Said plainly: a return is stock leaving and a bill coming down,
                    // and people expect one without the other.
                    Text("\(Money.text(total)) comes off what you owe, and the stock leaves your shelves.")
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.scaled(13))
                        .foregroundColor(.sDestructive)
                }
            }
        }
        .navigationTitle("Return to supplier")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Send back") { save() }.disabled(!canSave)
            }
        }
        .task { await loadBill() }
    }

    private func loadBill() async {
        guard let companyID = SessionManager.shared.selectedCompanyId else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            detail = try await PurchasesService().billDetail(companyID: companyID, billID: bill.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save() {
        let items: [PurchaseReturnLineRequest] = lines.compactMap { line in
            guard let qty = Int(sending[line.item_id] ?? ""), qty > 0 else { return nil }
            return PurchaseReturnLineRequest(
                item_id: line.item_id, qty: qty, rate: line.rate, tax_rate: line.tax_rate
            )
        }
        guard !items.isEmpty else { return }

        let request = NewPurchaseReturnRequest(
            supplier_id: bill.supplier_id,
            bill_id: bill.id,
            return_number: returnNumber.trimmingCharacters(in: .whitespaces),
            return_date: nil,
            reason: reason.isEmpty ? nil : reason,
            notes: nil,
            items: items
        )

        Task {
            if await vm.recordReturn(request) { dismiss() }
        }
    }
}
