//
//  PurchaseSheets.swift
//  Invo Billing
//
//  Adding a supplier, recording their bill, and paying them.
//

import SwiftUI

// MARK: - Adding a supplier

struct AddSupplierSheet: View {
    @ObservedObject var vm: PurchasesViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var phone = ""
    @State private var gstin = ""
    @State private var city = ""

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $name)
                TextField("Phone", text: $phone)
                    .keyboardType(.phonePad)
            } footer: {
                Text("The name is all that's needed. The rest helps when you're checking a statement.")
            }

            Section {
                TextField("GSTIN", text: $gstin)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                TextField("City", text: $city)
            }
        }
        .navigationTitle("Add supplier")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    Task {
                        let request = NewSupplierRequest(
                            name: name.trimmingCharacters(in: .whitespaces),
                            phone: phone.isEmpty ? nil : phone,
                            email: nil,
                            gstin: gstin.isEmpty ? nil : gstin,
                            city: city.isEmpty ? nil : city,
                            state: nil
                        )
                        if await vm.addSupplier(request) { dismiss() }
                    }
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || vm.isWorking)
            }
        }
    }
}

// MARK: - Recording a bill

/// A supplier's bill, recorded as a final amount or with stock lines.
struct RecordPurchaseBillSheet: View {
    @ObservedObject var vm: PurchasesViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var supplierID: Int?
    @State private var billNumber = ""
    @State private var billDate = Date()
    @State private var dueDate = Date().addingTimeInterval(30 * 24 * 60 * 60)
    @State private var hasDueDate = true
    @State private var paidNow = ""
    @State private var paidMethod = "Cash"
    @State private var entryMode = EntryMode.amountOnly
    @State private var invoiceAmount = ""
    @State private var notes = ""

    private enum EntryMode: String, CaseIterable {
        case amountOnly = "Amount only"
        case items = "With items"
    }

    @State private var lines: [DraftLine] = []
    @State private var showItemPicker = false

    /// One row of the bill while it is being entered.
    struct DraftLine: Identifiable {
        let id = UUID()
        var item: ItemResponse
        var qty: String
        var rate: String
        var taxRate: Double
    }

    private var subtotal: Double {
        lines.reduce(0) { $0 + (Double($1.qty) ?? 0) * (PurchaseAmountInput.parse($1.rate) ?? 0) }
    }
    private var tax: Double {
        lines.reduce(0) { sum, line in
            let net = (Double(line.qty) ?? 0) * (PurchaseAmountInput.parse(line.rate) ?? 0)
            return sum + net * line.taxRate / 100
        }
    }
    private var invoiceAmountValue: Double? { PurchaseAmountInput.parse(invoiceAmount) }
    private var total: Double {
        entryMode == .amountOnly ? (invoiceAmountValue ?? 0) : subtotal + tax
    }
    private var parsedPaid: Double? { PurchaseAmountInput.parse(paidNow, emptyAsZero: true) }
    private var paidValue: Double { parsedPaid ?? 0 }
    private var validItems: Bool {
        !lines.isEmpty && lines.allSatisfy { line in
            guard let qty = Int(line.qty), qty > 0, qty <= Int(Int32.max),
                  PurchaseAmountInput.parse(line.rate) != nil else { return false }
            return line.taxRate.isFinite && (0...100).contains(line.taxRate)
        }
    }
    private var canSave: Bool {
        supplierID != nil
            && !billNumber.trimmingCharacters(in: .whitespaces).isEmpty
            && (entryMode == .amountOnly ? (invoiceAmountValue ?? 0) > 0 : validItems)
            && total.isFinite && total <= 9_999_999_999.99
            && parsedPaid != nil
            && paidValue <= total + 0.004
            && !vm.isWorking
    }

    var body: some View {
        Form {
            Section {
                Picker("Entry type", selection: $entryMode) {
                    ForEach(EntryMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            } footer: {
                Text(entryMode == .amountOnly
                     ? "Record the invoice in the supplier ledger without changing stock."
                     : "Record the items received and update stock and cost prices.")
            }

            Section("Supplier") {
                Picker("Supplier", selection: $supplierID) {
                    Text("Choose").tag(Int?.none)
                    ForEach(vm.suppliers) { supplier in
                        Text(supplier.name).tag(Int?.some(supplier.id))
                    }
                }
                TextField("Supplier invoice number", text: $billNumber)
                    .autocorrectionDisabled()
                DatePicker("Bill date", selection: $billDate, displayedComponents: .date)
                Toggle("Payment due date", isOn: $hasDueDate)
                if hasDueDate {
                    DatePicker("Due", selection: $dueDate, displayedComponents: .date)
                }
            }

            if entryMode == .amountOnly {
                Section {
                    TextField("Invoice amount (₹)", text: $invoiceAmount)
                        .keyboardType(.decimalPad)
                        .accessibilityLabel("Invoice amount in rupees")
                    if !invoiceAmount.isEmpty && (invoiceAmountValue ?? 0) <= 0 {
                        Text("Enter an amount greater than zero, using digits and up to two decimal places.")
                            .font(.scaled(12))
                            .foregroundColor(.sDestructive)
                    }
                } header: {
                    Text("Invoice amount")
                } footer: {
                    Text("Enter the final total, including any GST. No item or GST breakdown is recorded.")
                }
            } else {
                Section {
                    ForEach($lines) { $line in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(line.item.name)
                                .font(.scaled(14, weight: .medium))
                            HStack {
                                Text("Qty").font(.scaled(12)).foregroundColor(.sMutedFG)
                                TextField("0", text: $line.qty)
                                    .keyboardType(.numberPad)
                                    .frame(width: 60)
                                Text("Rate").font(.scaled(12)).foregroundColor(.sMutedFG)
                                TextField("0.00", text: $line.rate)
                                    .keyboardType(.decimalPad)
                                    .frame(width: 90)
                                Spacer()
                                Text(Money.text((Double(line.qty) ?? 0) * (PurchaseAmountInput.parse(line.rate) ?? 0)))
                                    .font(.scaled(13, weight: .medium))
                            }
                        }
                    }
                    .onDelete { lines.remove(atOffsets: $0) }

                    Button {
                        showItemPicker = true
                    } label: {
                        Label("Add item", systemImage: "plus")
                    }
                } header: {
                    Text("Items")
                } footer: {
                    if !lines.isEmpty {
                        // Said plainly, because this is the part that surprises people: a
                        // bill does not just record a debt, it brings the stock in and
                        // changes what each item is costing them.
                        Text("Saving adds this stock and updates each item's cost price to the rate here.")
                    }
                }
            }

            if entryMode == .items && !lines.isEmpty {
                Section("Total") {
                    LabeledContent("Subtotal", value: Money.text(subtotal))
                    LabeledContent("GST", value: Money.text(tax))
                    LabeledContent("Total", value: Money.text(total))
                        .font(.scaled(15, weight: .semibold))
                }
            }

            if entryMode == .amountOnly || !lines.isEmpty {
                Section("Paid now") {
                    TextField("0.00", text: $paidNow)
                        .keyboardType(.decimalPad)
                    Picker("How", selection: $paidMethod) {
                        ForEach(["Cash", "UPI", "Bank transfer", "Cheque"], id: \.self) {
                            Text($0).tag($0)
                        }
                    }
                    if parsedPaid == nil {
                        Text("Enter a valid paid amount, or leave blank if unpaid.")
                            .font(.scaled(12))
                            .foregroundColor(.sDestructive)
                    } else if paidValue > total + 0.004 {
                        Text("That's more than the bill comes to.")
                            .font(.scaled(12))
                            .foregroundColor(.sDestructive)
                    } else if total - paidValue > 0 {
                        Text("\(Money.text(total - paidValue)) will be owed to this supplier.")
                            .font(.scaled(12))
                            .foregroundColor(.sMutedFG)
                    }
                }
            }

            Section("Notes") {
                TextField("Optional note", text: $notes, axis: .vertical)
            }

            if let error = vm.errorMessage {
                Section {
                    Text(error).foregroundColor(.sDestructive)
                }
            }
        }
        .navigationTitle("Record bill")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") { save() }.disabled(!canSave)
            }
        }
        .sheet(isPresented: $showItemPicker) {
            PurchaseItemPicker { item in
                lines.append(DraftLine(
                    item: item,
                    qty: "1",
                    // Starts from what it last cost, which is usually right and is
                    // always a better guess than an empty box.
                    rate: item.cost_price.map { String(format: "%.2f", $0) } ?? "",
                    taxRate: item.tax_rate ?? 18
                ))
            }
        }
    }

    private func save() {
        guard canSave, let supplierID else { return }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)

        let request = NewPurchaseBillRequest(
            supplier_id: supplierID,
            bill_number: billNumber.trimmingCharacters(in: .whitespaces),
            bill_date: formatter.string(from: billDate),
            due_date: hasDueDate ? formatter.string(from: dueDate) : nil,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes,
            items: entryMode == .amountOnly ? [] : lines.compactMap { line in
                guard let qty = Int(line.qty), qty > 0 else { return nil }
                return PurchaseLineRequest(
                    item_id: line.item.id,
                    qty: qty,
                    rate: PurchaseAmountInput.parse(line.rate) ?? 0,
                    tax_rate: line.taxRate
                )
            },
            paid_amount: paidValue,
            paid_method: paidValue > 0 ? paidMethod : nil,
            bill_amount: entryMode == .amountOnly ? invoiceAmountValue : nil
        )

        Task {
            if await vm.recordBill(request) { dismiss() }
        }
    }
}

/// Picking an item to put on a bill. The catalogue, searchable, nothing else.
private struct PurchaseItemPicker: View {
    let onPick: (ItemResponse) -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var itemVM = ItemViewModel()
    @State private var search = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(itemVM.items.filter {
                    search.isEmpty || $0.name.localizedCaseInsensitiveContains(search)
                }) { item in
                    Button {
                        onPick(item)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name).foregroundColor(.sForeground)
                            Text("\(item.quantity) in stock · last cost \(Money.text(item.cost_price ?? 0))")
                                .font(.scaled(12))
                                .foregroundColor(.sMutedFG)
                        }
                    }
                }
            }
            .searchable(text: $search)
            .navigationTitle("Add item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task { await itemVM.loadItems() }
        }
    }
}

// MARK: - Paying a supplier

struct PaySupplierSheet: View {
    let supplier: Supplier
    @ObservedObject var vm: PurchasesViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var amount = ""
    @State private var method = "Cash"
    @State private var reference = ""

    var body: some View {
        Form {
            Section {
                LabeledContent("Owed", value: Money.text(supplier.due))
                TextField("Amount", text: $amount)
                    .keyboardType(.decimalPad)
                Picker("How", selection: $method) {
                    ForEach(["Cash", "UPI", "Bank transfer", "Cheque"], id: \.self) {
                        Text($0).tag($0)
                    }
                }
                TextField("Reference (optional)", text: $reference)
            } footer: {
                Text("Goes against their oldest unpaid bills first. Paying more than is owed is kept as an advance.")
            }
        }
        .navigationTitle("Pay \(supplier.name)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    guard let value = Double(amount), value > 0 else { return }
                    Task {
                        let request = SupplierPaymentRequestDTO(
                            supplier_id: supplier.id,
                            bill_id: nil,
                            amount: value,
                            method: method,
                            reference: reference.isEmpty ? nil : reference,
                            paid_on: nil
                        )
                        if await vm.pay(request) { dismiss() }
                    }
                }
                .disabled((Double(amount) ?? 0) <= 0 || vm.isWorking)
            }
        }
        .onAppear {
            if supplier.due > 0 { amount = String(format: "%.2f", supplier.due) }
        }
    }
}
