import SwiftUI

struct PaymentsView: View {
    @EnvironmentObject private var session: SessionManager
    @StateObject private var vm = PaymentsViewModel()
    @State private var showFilters = false
    @State private var reversing: PaymentHistoryRow?
    @State private var moving: PaymentHistoryRow?
    @State private var refunding: PaymentHistoryRow?
    @State private var reversalReason = ""

    var body: some View {
        List {
            if vm.hasFilters {
                HStack {
                    Text("Filtered payments").font(.footnote).foregroundStyle(.secondary)
                    Spacer()
                    Button("Clear filters") { vm.clearFilters() }
                }
            }
            if vm.isLoading && vm.payments.isEmpty {
                ProgressView("Loading payments…").frame(maxWidth: .infinity)
            } else if vm.payments.isEmpty {
                ContentUnavailableView {
                    Label(vm.loadError != nil ? "Couldn't load payments" : vm.hasFilters ? "No matching payments" : "No payments yet",
                          systemImage: "indianrupeesign.circle")
                } description: {
                    Text(vm.loadError ?? "Payments you record against invoices appear here.")
                } actions: {
                    if vm.loadError != nil { Button("Retry") { Task { await vm.load() } } }
                }.listRowSeparator(.hidden)
            } else {
                if vm.loadError != nil {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Couldn't refresh. Showing the previous payments.").font(.footnote)
                        Button("Retry") { Task { await vm.load() } }
                    }
                }
                ForEach(vm.payments) { payment in
                    NavigationLink {
                        PaymentHistoryDetailView(payment: payment, vm: vm,
                            reverse: { reversing = $0 }, move: { moving = $0 }, refund: { refunding = $0 })
                    } label: { paymentRow(payment) }
                    .standardListRow()
                    .swipeActions(edge: .trailing) {
                        if !payment.isReversed {
                            Button("Reverse") { reversing = payment }.tint(.red)
                            if payment.canMove { Button("Move") { moving = payment }.tint(.sAccent) }
                        }
                    }
                    .task { await vm.loadMoreIfNeeded(currentItem: payment) }
                }
                if vm.isLoadingMore { ProgressView("Loading more payments…") }
                if vm.loadMoreFailed {
                    Button("Retry more payments") { Task { await vm.retryLoadMore() } }
                }
            }
        }
        .listStyle(.plain)
        .contentMargins(.bottom, 16, for: .scrollContent)
        .refreshable { await vm.load() }
        .navigationTitle("Payments")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $vm.search, prompt: "Client, invoice or reference")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showFilters = true } label: { Label("Filter payments", systemImage: "line.3.horizontal.decrease") }
            }
        }
        .task(id: "\(session.selectedCompanyId ?? 0):\(vm.query)") { await vm.load(debounce: true) }
        .sheet(isPresented: $showFilters) { PaymentFiltersSheet(vm: vm) }
        .alert("Payments", isPresented: $vm.showError) {
            Button("OK", role: .cancel) {}
        } message: { Text(vm.errorMessage ?? "Something went wrong") }
        .alert("Reverse this payment?", isPresented: Binding(
            get: { reversing != nil }, set: { if !$0 { reversing = nil; reversalReason = "" } }
        )) {
            TextField("Reason", text: $reversalReason)
            Button("Cancel", role: .cancel) { reversing = nil; reversalReason = "" }
            Button("Reverse", role: .destructive) {
                if let payment = reversing {
                    let reason = reversalReason.trimmingCharacters(in: .whitespacesAndNewlines)
                    Task { await vm.reverse(payment, reason: reason) }
                }
                reversing = nil; reversalReason = ""
            }.disabled(reversalReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isWorking)
        } message: {
            if let payment = reversing {
                Text("Reverse \(Money.text(payment.totalSettled)) settled for \(payment.client_name)? Its invoice allocations will be restored to owing. The reason stays in payment history.")
            }
        }
        .sheet(item: $moving) { payment in NavigationStack { MovePaymentSheet(payment: payment, vm: vm) } }
        .sheet(item: $refunding) { payment in
            NavigationStack {
                RefundSheet(clientID: payment.client_id, clientName: payment.client_name,
                    suggestedAmount: payment.onAccount, vm: vm)
            }
        }
    }

    private func paymentRow(_ payment: PaymentHistoryRow) -> some View {
        AdaptiveFormRow {
            VStack(alignment: .leading, spacing: 4) {
                Text(payment.client_name.isEmpty ? "Client" : payment.client_name).font(.body.weight(.medium))
                Text("\(AppDate.text(fromWire: payment.payment_date)) · \(payment.payment_method)")
                    .font(.footnote).foregroundStyle(.secondary)
                if !payment.reference.isEmpty { Text(payment.reference).font(.footnote).foregroundStyle(.secondary).lineLimit(2) }
                if payment.isReversed { Label("Reversed", systemImage: "arrow.uturn.backward").font(.caption).foregroundStyle(Color.sDestructive) }
            }.frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 4) {
                Text(Money.text(payment.amount)).font(.subheadline.weight(.semibold)).moneyLine()
                Text("Money received").font(.caption).foregroundStyle(.secondary)
                if payment.taxWithheld > 0 {
                    Text("TDS \(Money.text(payment.taxWithheld))").font(.footnote).foregroundStyle(.secondary)
                }
                if !payment.isReversed && payment.onAccount > 0 {
                    Text("\(Money.text(payment.onAccount)) on account").font(.caption).foregroundStyle(Color.sAccent)
                }
            }
        }
    }
}

private struct PaymentHistoryDetailView: View {
    let payment: PaymentHistoryRow
    @ObservedObject var vm: PaymentsViewModel
    let reverse: (PaymentHistoryRow) -> Void
    let move: (PaymentHistoryRow) -> Void
    let refund: (PaymentHistoryRow) -> Void
    private var current: PaymentHistoryRow { vm.payments.first { $0.id == payment.id } ?? payment }

    var body: some View {
        Form {
            Section("Payment") {
                LabeledContent("Client", value: current.client_name)
                LabeledContent("Date", value: AppDate.text(fromWire: current.payment_date))
                LabeledContent("Money received", value: Money.text(current.amount))
                if current.taxWithheld > 0 {
                    LabeledContent("TDS withheld", value: Money.text(current.taxWithheld))
                    LabeledContent("Total settled", value: Money.text(current.totalSettled))
                }
                LabeledContent("Method", value: current.payment_method)
                LabeledContent("Payment ID", value: String(current.id))
                LabeledContent("Status", value: current.isReversed ? "Reversed" : "Recorded")
                if !current.reference.isEmpty { LabeledContent("Reference", value: current.reference).textSelection(.enabled) }
                if !current.notes.isEmpty { Text(current.notes).textSelection(.enabled) }
            }
            Section("Invoice allocations") {
                ForEach(current.invoices) { allocation in
                    LabeledContent(allocation.invoice_number, value: Money.text(allocation.amount))
                }
                if current.invoices.isEmpty && !current.applied_to.isEmpty { Text(current.applied_to) }
                if current.onAccount > 0 { LabeledContent("On account", value: Money.text(current.onAccount)) }
            }
            if let reason = current.reversal_reason, !reason.isEmpty {
                Section("Reversal reason") { Text(reason).textSelection(.enabled) }
            }
            if !current.isReversed {
                Section("Correct payment") {
                    if current.canMove { Button("Move to other invoices") { move(current) } }
                    else { Text("To correct a payment containing TDS, reverse it and record the correct money and withholding amounts.").font(.footnote).foregroundStyle(.secondary) }
                    if current.onAccount > 0 { Button("Refund money on account") { refund(current) } }
                    Button("Reverse payment", role: .destructive) { reverse(current) }
                }.disabled(vm.isWorking)
            }
            Section { ShareLink("Share payment summary", item: shareText) }
        }
        .navigationTitle("Payment details")
        .navigationBarTitleDisplayMode(.inline)
        .overlay { if vm.isWorking { ProgressView("Saving…").padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12)) } }
    }

    private var shareText: String {
        var lines = ["Payment #\(current.id)", current.client_name,
            "Date: \(AppDate.text(fromWire: current.payment_date))",
            "Money received: \(Money.text(current.amount))", "Method: \(current.payment_method)"]
        if current.taxWithheld > 0 { lines += ["TDS withheld: \(Money.text(current.taxWithheld))", "Total settled: \(Money.text(current.totalSettled))"] }
        if !current.reference.isEmpty { lines.append("Reference: \(current.reference)") }
        lines += current.invoices.map { "\($0.invoice_number): \(Money.text($0.amount))" }
        if current.isReversed { lines.append("Reversed: \(current.reversal_reason ?? "")") }
        return lines.joined(separator: "\n")
    }
}

private struct PaymentFiltersSheet: View {
    @ObservedObject var vm: PaymentsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var method = ""
    @State private var useDates = false
    @State private var start = Date()
    @State private var end = Date()
    @State private var clientID: Int?
    @State private var clientName = ""
    @State private var choosingClient = false
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Payment method", selection: $method) {
                        Text("All methods").tag("")
                        ForEach(["Cash", "UPI", "Bank transfer", "Cheque", "Card"], id: \.self) { Text($0).tag($0) }
                    }
                    Button { choosingClient = true } label: {
                        LabeledContent("Client", value: clientID == nil ? "All clients" : clientName)
                    }
                    if clientID != nil { Button("All clients") { clientID = nil; clientName = "" } }
                }
                Section {
                    Toggle("Filter by date", isOn: $useDates)
                    if useDates {
                        DatePicker("From", selection: $start, displayedComponents: .date)
                        DatePicker("Through", selection: $end, in: start..., displayedComponents: .date)
                    }
                }
            }
            .navigationTitle("Payment filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        vm.method = method; vm.clientID = clientID; vm.clientName = clientName
                        vm.startDate = useDates ? start : nil; vm.endDate = useDates ? max(start, end) : nil
                        dismiss()
                    }
                }
            }
            .onAppear {
                method = vm.method; clientID = vm.clientID; clientName = vm.clientName
                useDates = vm.startDate != nil
                start = vm.startDate ?? Date(); end = vm.endDate ?? Date()
            }
            .sheet(isPresented: $choosingClient) {
                PaymentClientPicker { client in clientID = client.id; clientName = client.name }
            }
        }
    }
}

private struct PaymentClientPicker: View {
    let onPick: (ClientModel) -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = ClientViewModel()
    var body: some View {
        NavigationStack {
            List {
                if vm.isLoading && vm.clients.isEmpty { ProgressView("Loading clients…") }
                if let error = vm.errorMessage { Text(error); Button("Retry") { Task { await vm.loadClients() } } }
                ForEach(vm.clients) { client in
                    Button { onPick(client); dismiss() } label: {
                        Text(client.name).foregroundStyle(.primary)
                    }.task { if client.id == vm.clients.suffix(5).first?.id { await vm.loadMoreClients() } }
                }
                if vm.isLoadingMoreClients { ProgressView() }
                if vm.loadMoreClientsFailed { Button("Retry more clients") { Task { await vm.retryLoadMoreClients() } } }
                if !vm.isLoading && vm.clients.isEmpty && vm.errorMessage == nil { ContentUnavailableView.search(text: vm.searchText) }
            }
            .searchable(text: $vm.searchText, prompt: "Client name or phone")
            .navigationTitle("Choose client")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .task(id: vm.searchText) {
                do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
                await vm.loadClients()
            }
        }
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
    @State private var originalAmounts: [Int: String] = [:]
    @State private var confirmDiscard = false

    private var allocated: Double {
        amounts.values.reduce(0) { $0 + (Money.parse($1) ?? 0) }
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
                        AdaptiveFormRow {
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
                            guard let value = Money.parse(pair.value), value > 0 else { return nil }
                            return (invoiceID: pair.key, amount: value)
                        }
                        Task {
                            if await vm.move(payment, to: allocations) { dismiss() }
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
                    .disabled(overAllocated || vm.isWorking || vm.isLoadingInvoices || !payment.canMove || amounts.values.contains { !$0.isEmpty && Money.parse($0) == nil })
                }
                .padding(AppSpacing.card)
            }
        }
        .protectUnsavedChanges(isDirty: amounts != originalAmounts, confirmDiscard: $confirmDiscard) { dismiss() }
        .navigationTitle("Move payment")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { if amounts != originalAmounts { confirmDiscard = true } else { dismiss() } }
            }
        }
        .task {
            await vm.loadInvoices(for: payment)
            // Start from what it is on now, so a small correction is a small edit.
            for allocation in payment.invoices {
                amounts[allocation.invoice_id] = Money.editable(allocation.amount)
            }
            originalAmounts = amounts
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
                        Picker("Payment method", selection: $method) {
                            ForEach(methods, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.menu)
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
                        guard let value = Money.parse(amount), value > 0 else { return }
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
                            .background((Money.parse(amount) ?? 0) > 0 ? Color.sAccent : Color.sMutedFG.opacity(0.4))
                            .cornerRadius(12)
                    }
                    .disabled((Money.parse(amount) ?? 0) <= 0 || vm.isWorking)
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
