//
//  CreditNoteActionSheets.swift
//  Invo Billing
//
//  Spending a credit note: against an invoice, or handed back as cash.
//

import SwiftUI

// MARK: - Putting it against an invoice

struct ApplyCreditSheet: View {
    let creditNote: CreditNoteDetailModel
    let onDone: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var invoices: [InvoiceSummaryModel] = []
    @State private var selected: InvoiceSummaryModel?
    @State private var amount = ""
    @State private var isLoading = true
    @State private var isWorking = false
    @State private var errorMessage: String?

    /// What this invoice can take, which is the most that should go against it.
    private var cap: Double {
        guard let selected else { return creditNote.balance }
        return min(creditNote.balance, selected.remainingAmount)
    }

    private var amountValue: Double { Double(amount) ?? cap }
    private var canApply: Bool {
        selected != nil && amountValue > 0 && amountValue <= cap + 0.004 && !isWorking
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("Credit left", value: Money.text(creditNote.balance))
            } footer: {
                Text("Choose which of \(creditNote.client_name)'s unpaid invoices this should settle.")
            }

            Section("Unpaid invoices") {
                if isLoading {
                    HStack {
                        ProgressView().tint(.sAccent)
                        Text("Loading…").font(.scaled(13)).foregroundColor(.sMutedFG)
                    }
                } else if invoices.isEmpty {
                    Text("Nothing of theirs is unpaid. The credit can be refunded instead.")
                        .font(.scaled(13))
                        .foregroundColor(.sMutedFG)
                } else {
                    ForEach(invoices) { invoice in
                        Button {
                            selected = invoice
                            amount = ""
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(invoice.invoiceNumber)
                                        .font(.scaled(14, weight: .medium))
                                        .foregroundColor(.sForeground)
                                    Text("\(Money.text(invoice.remainingAmount)) owing")
                                        .font(.scaled(12))
                                        .foregroundColor(.sMutedFG)
                                }
                                Spacer()
                                if selected?.id == invoice.id {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.sAccent)
                                }
                            }
                        }
                    }
                }
            }

            if selected != nil {
                Section {
                    TextField(Money.text(cap), text: $amount)
                        .keyboardType(.decimalPad)
                } header: {
                    Text("How much")
                } footer: {
                    if amountValue > cap + 0.004 {
                        Text("That's more than this invoice can take.")
                            .foregroundColor(.sDestructive)
                    } else {
                        // Said plainly, because a credit note is not money moving and
                        // people reasonably expect it to behave like a payment.
                        Text("Leave it blank to put the whole \(Money.text(cap)) against this invoice. Nothing is paid out — the customer was credited when the note was issued.")
                    }
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
        .navigationTitle("Apply to invoice")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Apply") { apply() }.disabled(!canApply)
            }
        }
        .task { await loadInvoices() }
    }

    private func loadInvoices() async {
        isLoading = true
        defer { isLoading = false }
        do {
            invoices = try await CreditNoteService.shared
                .unpaidInvoices(clientID: creditNote.client_id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func apply() {
        guard let invoice = selected else { return }
        isWorking = true
        errorMessage = nil

        Task {
            do {
                try await CreditNoteService.shared.applyToInvoice(
                    creditNoteID: creditNote.id,
                    invoiceID: invoice.id,
                    amount: amount.isEmpty ? nil : amountValue
                )
                onDone()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isWorking = false
        }
    }
}

// MARK: - Handing the money back

struct RefundCreditSheet: View {
    let creditNote: CreditNoteDetailModel
    let onDone: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var amount = ""
    @State private var method = "Cash"
    @State private var reference = ""
    @State private var isWorking = false
    @State private var errorMessage: String?

    private var amountValue: Double { Double(amount) ?? creditNote.balance }
    private var canRefund: Bool {
        amountValue > 0 && amountValue <= creditNote.balance + 0.004 && !isWorking
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("Credit left", value: Money.text(creditNote.balance))
                TextField(Money.text(creditNote.balance), text: $amount)
                    .keyboardType(.decimalPad)
                Picker("How", selection: $method) {
                    ForEach(["Cash", "UPI", "Bank transfer", "Cheque"], id: \.self) {
                        Text($0).tag($0)
                    }
                }
                TextField("Reference (optional)", text: $reference)
            } footer: {
                if amountValue > creditNote.balance + 0.004 {
                    Text("That's more than this credit note has left.")
                        .foregroundColor(.sDestructive)
                } else {
                    Text("Money going back to \(creditNote.client_name). Cash refunds come out of the drawer and show on that day's closing.")
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
        .navigationTitle("Refund credit")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Refund") { refund() }.disabled(!canRefund)
            }
        }
    }

    private func refund() {
        isWorking = true
        errorMessage = nil

        Task {
            do {
                try await CreditNoteService.shared.refund(
                    creditNoteID: creditNote.id,
                    clientID: creditNote.client_id,
                    amount: amountValue,
                    method: method,
                    reference: reference
                )
                onDone()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isWorking = false
        }
    }
}
