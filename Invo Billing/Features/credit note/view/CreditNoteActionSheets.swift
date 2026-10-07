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

    /// True when the box has been left alone. Blank means "all of it" here, which the
    /// footer says in so many words.
    private var isBlank: Bool {
        amount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// What was typed, read strictly — nil when it cannot be read as an amount, which
    /// is a different thing from the box being empty.
    private var typedAmount: Double? { Money.parse(amount) }

    /// True when there is something in the box that is not an amount. This used to be
    /// indistinguishable from blank: `Double(amount) ?? cap` turned anything
    /// unreadable into the largest allowed value, so a slip of the thumb put the whole
    /// credit against the invoice with the button looking perfectly happy about it.
    private var amountIsUnreadable: Bool { !isBlank && typedAmount == nil }

    /// What will actually be applied.
    private var amountValue: Double { typedAmount ?? cap }

    private var canApply: Bool {
        selected != nil && !amountIsUnreadable
            && amountValue > 0 && amountValue <= cap + 0.004 && !isWorking
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
                    if amountIsUnreadable {
                        Text("Enter the amount in rupees — 1500, or 1500.50.")
                            .foregroundColor(.sDestructive)
                    } else if amountValue > cap + 0.004 {
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
                    // Blank sends nothing, which the server reads as the whole of it.
                    // Anything else has been read strictly to get here.
                    amount: isBlank ? nil : typedAmount
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

    /// The amount to hand back, read strictly. Nil means the box does not currently
    /// hold an amount, and nothing is paid out on a nil.
    ///
    /// This is money leaving the drawer, so there is no "blank means all of it" here
    /// the way there is when applying credit to an invoice. The field is filled in with
    /// the full balance when the sheet opens, so the common case — refunding the lot —
    /// is still one tap, but the figure being paid is always on screen and always
    /// something somebody can see and change. What it replaces was the opposite of
    /// that: `Double(amount) ?? creditNote.balance` meant an empty box and a typo both
    /// came out as the entire balance, and the sheet opened empty with the balance only
    /// as grey placeholder text, so opening it and tapping Refund paid out everything.
    private var typedAmount: Double? { Money.parse(amount) }

    private var canRefund: Bool {
        guard let value = typedAmount else { return false }
        return value > 0 && value <= creditNote.balance + 0.004 && !isWorking
    }

    /// True when there is something in the box that is not an amount, so the footer can
    /// say why the button will not move.
    private var amountIsUnreadable: Bool {
        !amount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && typedAmount == nil
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
                if amountIsUnreadable {
                    Text("Enter the amount in rupees — 1500, or 1500.50.")
                        .foregroundColor(.sDestructive)
                } else if let value = typedAmount, value > creditNote.balance + 0.004 {
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
        // Filled in rather than hinted at. The figure about to be paid out is on screen
        // as a real, editable value from the moment the sheet opens.
        .onAppear {
            if amount.isEmpty { amount = Money.editable(creditNote.balance) }
        }
    }

    private func refund() {
        // Nothing is paid out on an amount that could not be read. The button is
        // already disabled in that case; this is the same answer given twice, because
        // the one thing this screen must never do is guess at a figure.
        guard let value = typedAmount, value > 0 else { return }
        isWorking = true
        errorMessage = nil

        Task {
            do {
                try await CreditNoteService.shared.refund(
                    creditNoteID: creditNote.id,
                    clientID: creditNote.client_id,
                    amount: value,
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
