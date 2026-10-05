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
        ZStack {
            Color.sBackground.ignoresSafeArea()

            if vm.isLoading && vm.payments.isEmpty {
                ProgressView().tint(.sAccent)
            } else if vm.payments.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(vm.payments) { payment in
                            paymentCard(payment)
                                .task { await vm.loadMoreIfNeeded(currentItem: payment) }
                        }

                        if vm.loadMoreFailed {
                            VStack(spacing: 6) {
                                Text("Couldn't load more payments.")
                                    .font(.scaled(13))
                                    .foregroundColor(.sMutedFG)
                                Button("Try again") { Task { await vm.retryLoadMore() } }
                                    .font(.scaled(13, weight: .medium))
                                    .foregroundColor(.sAccent)
                            }
                            .padding(.vertical, 12)
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
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
        VStack(spacing: 10) {
            Image(systemName: "indianrupeesign.circle")
                .font(.scaled(30))
                .foregroundColor(.sMutedFG)
            Text("No payments yet")
                .font(.scaled(15, weight: .medium))
                .foregroundColor(.sForeground)
            Text("Payments you record against invoices appear here.")
                .font(.scaled(12))
                .foregroundColor(.sMutedFG)
        }
    }

    private func paymentCard(_ payment: PaymentHistoryRow) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(payment.client_name.isEmpty ? "—" : payment.client_name)
                        .font(.scaled(14, weight: .medium))
                        .foregroundColor(.sForeground)
                    Text(subtitle(payment))
                        .font(.scaled(12))
                        .foregroundColor(.sMutedFG)
                }
                Spacer()
                Text(Money.text(payment.amount)).moneyLine()
                    .font(.scaled(15, weight: .semibold))
                    .foregroundColor(payment.isReversed ? .sMutedFG : .sForeground)
                    .strikethrough(payment.isReversed)
            }

            if payment.isReversed {
                Label(
                    payment.reversal_reason?.isEmpty == false
                        ? "Reversed — \(payment.reversal_reason!)"
                        : "Reversed",
                    systemImage: "arrow.uturn.backward"
                )
                .font(.scaled(12))
                .foregroundColor(.sDestructive)
            } else {
                if !payment.applied_to.isEmpty {
                    Text("Paid: \(payment.applied_to)")
                        .font(.scaled(12))
                        .foregroundColor(.sMutedFG)
                }
                if payment.onAccount > 0 {
                    // The advance. Worth stating plainly — it is money the shop is
                    // holding, and it is easy to forget it is there.
                    Text("\(Money.text(payment.onAccount)) on account")
                        .font(.scaled(12, weight: .medium))
                        .foregroundColor(.sAccent)
                }

                HStack(spacing: 16) {
                    Button("Move") { moving = payment }
                    Button("Reverse") { reversing = payment }
                        .foregroundColor(.sDestructive)
                    if payment.onAccount > 0 {
                        Button("Refund") { refunding = payment }
                    }
                }
                .font(.scaled(13, weight: .medium))
                .foregroundColor(.sAccent)
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.sCard)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.sBorder, lineWidth: 0.5))
        .cornerRadius(14)
        .opacity(payment.isReversed ? 0.7 : 1)
    }

    private func subtitle(_ payment: PaymentHistoryRow) -> String {
        var parts: [String] = [AppDate.shortText(fromWire: payment.payment_date)]
        if !payment.payment_method.isEmpty { parts.append(payment.payment_method) }
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
                            .font(.scaled(15, weight: .semibold))
                            .foregroundColor(.sForeground)
                        Text("Put it against the invoices it should have paid. Anything left over stays on the customer's account.")
                            .font(.scaled(12))
                            .foregroundColor(.sMutedFG)
                    }

                    if vm.isLoadingInvoices {
                        ProgressView().tint(.sAccent).frame(maxWidth: .infinity)
                    } else if vm.movableInvoices.isEmpty {
                        Text("This customer has nothing outstanding. Moving it now leaves the whole payment on their account.")
                            .font(.scaled(12))
                            .foregroundColor(.sMutedFG)
                    }

                    ForEach(vm.movableInvoices) { invoice in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(invoice.invoiceNumber)
                                    .font(.scaled(13, weight: .medium))
                                    .foregroundColor(.sForeground)
                                Text("\(Money.text(invoice.remainingAmount)) owing")
                                    .font(.scaled(12))
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
                            .font(.scaled(12))
                            .foregroundColor(.sDestructive)
                    } else if leftOver > 0 {
                        Text("\(Money.text(leftOver)) will stay on the customer's account.")
                            .font(.scaled(12))
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
                            .font(.scaled(15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(overAllocated ? Color.sMutedFG.opacity(0.4) : Color.sAccent)
                            .cornerRadius(12)
                    }
                    .disabled(overAllocated || vm.isWorking)
                }
                .padding(20)
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
                        .font(.scaled(15, weight: .semibold))
                        .foregroundColor(.sForeground)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Amount")
                            .font(.scaled(12))
                            .foregroundColor(.sMutedFG)
                        TextField("0.00", text: $amount)
                            .keyboardType(.decimalPad)
                            .padding(12)
                            .background(Color.sInput.opacity(0.5))
                            .cornerRadius(10)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("How")
                            .font(.scaled(12))
                            .foregroundColor(.sMutedFG)
                        Picker("", selection: $method) {
                            ForEach(methods, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Reference (optional)")
                            .font(.scaled(12))
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
                            .font(.scaled(15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background((Double(amount) ?? 0) > 0 ? Color.sAccent : Color.sMutedFG.opacity(0.4))
                            .cornerRadius(12)
                    }
                    .disabled((Double(amount) ?? 0) <= 0 || vm.isWorking)
                }
                .padding(20)
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
