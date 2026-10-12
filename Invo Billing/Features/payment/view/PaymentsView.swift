//
//  PaymentsView.swift
//  Invo Billing
//
//  Every payment taken, and what to do when one is wrong.
//
//  There was no way to see a payment after recording it, which meant there was no way
//  to correct one either — a payment entered against the wrong customer stayed wrong,
//  and the only workaround was a credit note that said nothing about what happened.
//

import SwiftUI

struct PaymentsView: View {
    @StateObject private var vm = PaymentsViewModel()

    @State private var reversing: PaymentHistoryRow?
    @State private var moving: PaymentHistoryRow?
    @State private var refunding: PaymentHistoryRow?
    @State private var reversalReason = ""

    var body: some View {
        Group {
            if vm.isLoading && vm.payments.isEmpty {
                ProgressView()
                    .tint(.sAccent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.payments.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(vm.payments) { payment in
                        paymentRow(payment)
                            .standardListRow(trailing: 12)
                            .listRowSeparator(.hidden, edges: payment.id == vm.payments.first?.id ? .top : [])
                            .swipeActions(edge: .trailing) {
                                if !payment.isReversed {
                                    // Not role: .destructive — that animates the row away before the reason is asked for.
                                    Button("Reverse") { reversing = payment }
                                        .tint(.red)
                                    Button("Move") { moving = payment }
                                        .tint(.sAccent)
                                }
                            }
                            .task { await vm.loadMoreIfNeeded(currentItem: payment) }
                    }

                    if vm.loadMoreFailed {
                        VStack(spacing: 6) {
                            Text("Couldn't load more payments.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Button("Try again") { Task { await vm.retryLoadMore() } }
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color.sAccent)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .contentMargins(.bottom, 16, for: .scrollContent)
                .refreshable { await vm.load() }
            }
        }
        .navigationTitle("Payments")
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.load() }
        .alert("Payments", isPresented: $vm.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.errorMessage ?? "Something went wrong")
        }
        // Reversing is the destructive one, so it asks for a reason rather than just a
        // confirmation: in three months the reason is the only thing that explains the
        // pair of entries on the customer's statement.
        .alert("Reverse this payment?", isPresented: Binding(
            get: { reversing != nil },
            set: { if !$0 { reversing = nil; reversalReason = "" } }
        )) {
            TextField("Reason (cheque bounced, entered twice…)", text: $reversalReason)
            Button("Cancel", role: .cancel) { reversing = nil; reversalReason = "" }
            Button("Reverse", role: .destructive) {
                if let payment = reversing {
                    let reason = reversalReason
                    Task { await vm.reverse(payment, reason: reason) }
                }
                reversing = nil
                reversalReason = ""
            }
        } message: {
            Text("The invoices it paid will go back to owing. The payment stays in the history, marked reversed.")
        }
        .sheet(item: $moving) { payment in
            NavigationStack {
                MovePaymentSheet(payment: payment, vm: vm)
            }
        }
        .sheet(item: $refunding) { payment in
            NavigationStack {
                RefundSheet(
                    clientID: payment.client_id,
                    clientName: payment.client_name,
                    suggestedAmount: payment.onAccount,
                    vm: vm
                )
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No payments yet",
            systemImage: "indianrupeesign.circle",
            description: Text("Payments you record against invoices appear here.")
        )
    }

    private func paymentRow(_ payment: PaymentHistoryRow) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(payment.client_name.isEmpty ? "—" : payment.client_name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(subtitle(payment))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if payment.isReversed {
                    Label(
                        payment.reversal_reason?.isEmpty == false
                            ? "Reversed — \(payment.reversal_reason!)"
                            : "Reversed",
                        systemImage: "arrow.uturn.backward"
                    )
                    .font(.caption)
                    .foregroundStyle(Color.sDestructive)
                    .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                Text(Money.text(payment.amount)).moneyLine()
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(payment.isReversed ? .secondary : .primary)
                    .strikethrough(payment.isReversed)
                if !payment.isReversed && payment.onAccount > 0 {
                    // The advance. Worth stating plainly — it is money the shop is
                    // holding, and it is easy to forget it is there.
                    Text("\(Money.text(payment.onAccount)) on account")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.sAccent)
                }
            }
            .frame(minWidth: 88, alignment: .trailing)

            if !payment.isReversed {
                Menu {
                    Button { moving = payment } label: {
                        Label("Move to other invoices", systemImage: "arrow.left.arrow.right")
                    }
                    if payment.onAccount > 0 {
                        Button { refunding = payment } label: {
                            Label("Refund", systemImage: "arrow.uturn.left.circle")
                        }
                    }
                    Divider()
                    Button(role: .destructive) { reversing = payment } label: {
                        Label("Reverse", systemImage: "arrow.uturn.backward")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.secondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Payment actions")
            } else {
                Color.clear.frame(width: 32, height: 32)
            }
        }
        .opacity(payment.isReversed ? 0.7 : 1)
    }

    private func subtitle(_ payment: PaymentHistoryRow) -> String {
        var parts: [String] = [AppDate.shortText(fromWire: payment.payment_date)]
        let method = payment.payment_method
        if !method.isEmpty { parts.append(method.count <= 3 ? method.uppercased() : method.capitalized) }
        if !payment.isReversed && !payment.applied_to.isEmpty { parts.append(payment.applied_to) }
        if !payment.reference.isEmpty { parts.append(payment.reference) }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Moving a payment

/// Putting a payment onto the invoices it should have settled.
private struct MovePaymentSheet: View {
    let payment: PaymentHistoryRow
    @ObservedObject var vm: PaymentsViewModel
    @Environment(\.dismiss) private var dismiss

    /// How much of the payment goes on each invoice, by invoice id.
    @State private var amounts: [Int: String] = [:]

    private var allocated: Double {
        amounts.values.reduce(0) { $0 + (Double($1) ?? 0) }
    }
    private var leftOver: Double { max(payment.amount - allocated, 0) }
    private var overAllocated: Bool { allocated > payment.amount + 0.004 }

    var body: some View {
        ZStack {
            Color.sBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(Money.text(payment.amount)) from \(payment.client_name)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.sForeground)
                        Text("Put it against the invoices it should have paid. Anything left over stays on the customer's account.")
                            .font(.footnote)
                            .foregroundColor(.sMutedFG)
                    }

                    if vm.isLoadingInvoices {
                        ProgressView().tint(.sAccent).frame(maxWidth: .infinity)
                    } else if vm.movableInvoices.isEmpty {
                        Text("This customer has nothing outstanding. Moving it now leaves the whole payment on their account.")
                            .font(.footnote)
                            .foregroundColor(.sMutedFG)
                    }

                    ForEach(vm.movableInvoices) { invoice in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(invoice.invoiceNumber)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.sForeground)
                                Text("\(Money.text(invoice.remainingAmount)) owing")
                                    .font(.footnote)
                                    .foregroundColor(.sMutedFG)
                            }
                            Spacer()
                            TextField("0", text: Binding(
                                get: { amounts[invoice.id] ?? "" },
                                set: { amounts[invoice.id] = $0 }
                            ))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                            .padding(8)
                            .background(Color.sInput.opacity(0.5))
                            .cornerRadius(8)
                        }
                        .padding(12)
                        .background(Color.sCard)
                        .cornerRadius(12)
                    }

                    if overAllocated {
                        Text("That's more than the payment is for.")
                            .font(.footnote)
                            .foregroundColor(.sDestructive)
                    } else if leftOver > 0 {
                        Text("\(Money.text(leftOver)) will stay on the customer's account.")
                            .font(.footnote)
                            .foregroundColor(.sMutedFG)
                    }

                    Button {
                        let allocations = amounts.compactMap { pair -> (invoiceID: Int, amount: Double)? in
                            guard let value = Double(pair.value), value > 0 else { return nil }
                            return (invoiceID: pair.key, amount: value)
                        }
                        Task {
                            await vm.move(payment, to: allocations)
                            dismiss()
                        }
                    } label: {
                        Text("Save")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(overAllocated ? Color.sMutedFG.opacity(0.4) : Color.sAccent)
                            .cornerRadius(12)
                    }
                    .disabled(overAllocated || vm.isWorking)
                }
                .padding(AppSpacing.card)
            }
        }
        .navigationTitle("Move payment")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
            }
        }
        .task {
            await vm.loadInvoices(for: payment)
            // Start from what it is on now, so a small correction is a small edit.
            for allocation in payment.invoices {
                amounts[allocation.invoice_id] = String(format: "%.2f", allocation.amount)
            }
        }
    }
}

// MARK: - Refunding

/// Money handed back: an advance the customer is not going to use.
private struct RefundSheet: View {
    let clientID: Int
    let clientName: String
    let suggestedAmount: Double
    @ObservedObject var vm: PaymentsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var amount = ""
    @State private var method = "Cash"
    @State private var reference = ""

    private let methods = ["Cash", "UPI", "Bank transfer", "Cheque"]

    var body: some View {
        ZStack {
            Color.sBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Returning money to \(clientName)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.sForeground)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Amount")
                            .font(.footnote)
                            .foregroundColor(.sMutedFG)
                        TextField("0.00", text: $amount)
                            .keyboardType(.decimalPad)
                            .padding(12)
                            .background(Color.sInput.opacity(0.5))
                            .cornerRadius(10)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("How")
                            .font(.footnote)
                            .foregroundColor(.sMutedFG)
                        Picker("", selection: $method) {
                            ForEach(methods, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Reference (optional)")
                            .font(.footnote)
                            .foregroundColor(.sMutedFG)
                        TextField("UPI reference, cheque number…", text: $reference)
                            .padding(12)
                            .background(Color.sInput.opacity(0.5))
                            .cornerRadius(10)
                    }

                    Button {
                        guard let value = Double(amount), value > 0 else { return }
                        let request = RefundRequestDTO(
                            client_id: clientID,
                            credit_note_id: nil,
                            amount: value,
                            method: method,
                            reference: reference.isEmpty ? nil : reference,
                            notes: nil,
                            refund_date: nil
                        )
                        Task {
                            if await vm.refund(request) { dismiss() }
                        }
                    } label: {
                        Text("Record refund")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background((Double(amount) ?? 0) > 0 ? Color.sAccent : Color.sMutedFG.opacity(0.4))
                            .cornerRadius(12)
                    }
                    .disabled((Double(amount) ?? 0) <= 0 || vm.isWorking)
                }
                .padding(AppSpacing.card)
            }
        }
        .navigationTitle("Refund")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
            }
        }
        .onAppear {
            if suggestedAmount > 0 { amount = String(format: "%.2f", suggestedAmount) }
        }
    }
}
