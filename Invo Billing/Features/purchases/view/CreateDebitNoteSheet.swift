import SwiftUI

// MARK: - Item picker (file-private so it doesn't clash with PurchaseSheets)

private struct DebitNoteItemPicker: View {
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
                                .font(.footnote).foregroundColor(.sMutedFG)
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

// MARK: -

/// Standalone debit note creation — no bill required.
/// The user picks a supplier, optionally links a bill, and enters the items going back.
struct CreateDebitNoteSheet: View {
    @ObservedObject var vm: PurchasesViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var supplierID: Int?
    @State private var returnNumber = ""
    @State private var returnDate = Date()
    @State private var reason = ""

    // Bill link
    @State private var supplierBills: [PurchaseBill] = []
    @State private var billID: Int?
    @State private var billDetail: PurchaseBillDetail?
    @State private var loadingBills = false
    @State private var loadingBillDetail = false

    // Items — either from a linked bill or entered manually
    @State private var billLines: [BillReturnLine] = []   // from bill
    @State private var manualLines: [ManualReturnLine] = [] // freehand
    @State private var showItemPicker = false

    struct BillReturnLine: Identifiable {
        let id = UUID()
        let line: PurchaseBillLine
        var qty: String = ""
    }

    struct ManualReturnLine: Identifiable {
        let id = UUID()
        var item: ItemResponse
        var qty: String = "1"
        var rate: String = ""
        var taxRate: Double = 0
    }

    private var selectedSupplier: Supplier? {
        vm.suppliers.first { $0.id == supplierID }
    }

    private var usingBill: Bool { billID != nil && !billLines.isEmpty }

    private var total: Double {
        if usingBill {
            return billLines.reduce(0) { sum, l in
                let qty = Double(l.qty) ?? 0
                let net = qty * l.line.rate
                return sum + net + net * l.line.tax_rate / 100
            }
        }
        return manualLines.reduce(0) { sum, l in
            let qty = Double(l.qty) ?? 0
            let net = qty * (Double(l.rate) ?? 0)
            return sum + net + net * l.taxRate / 100
        }
    }

    private var overReturning: Bool {
        billLines.contains { (Int($0.qty) ?? 0) > $0.line.qty }
    }

    private var canSave: Bool {
        guard supplierID != nil,
              !returnNumber.trimmingCharacters(in: .whitespaces).isEmpty,
              !vm.isWorking else { return false }
        if usingBill { return total > 0 && !overReturning }
        return !manualLines.isEmpty && manualLines.allSatisfy {
            (Int($0.qty) ?? 0) > 0 && (Double($0.rate) ?? 0) > 0
        }
    }

    var body: some View {
        Form {
            // ── Supplier & document ──────────────────────────────
            Section("Debit note") {
                Picker("Supplier", selection: $supplierID) {
                    Text("Choose").tag(Int?.none)
                    ForEach(vm.suppliers) { s in
                        Text(s.name).tag(Int?.some(s.id))
                    }
                }
                .onChange(of: supplierID) { _, _ in
                    billID = nil
                    billDetail = nil
                    billLines = []
                    Task { await loadBills() }
                }

                TextField("Debit note number", text: $returnNumber)
                    .autocorrectionDisabled()
                DatePicker("Date", selection: $returnDate, displayedComponents: .date)
                TextField("Reason (optional)", text: $reason)
            }

            // ── Optional bill link ───────────────────────────────
            if supplierID != nil {
                Section {
                    if loadingBills {
                        HStack {
                            ProgressView().tint(.sAccent)
                            Text("Loading bills…").font(.subheadline).foregroundColor(.sMutedFG)
                        }
                    } else if supplierBills.isEmpty {
                        Text("No open bills for this supplier.")
                            .font(.subheadline).foregroundColor(.sMutedFG)
                    } else {
                        Picker("Bill", selection: $billID) {
                            Text("None").tag(Int?.none)
                            ForEach(supplierBills) { b in
                                Text("\(b.bill_number) · \(Money.text(b.total))").tag(Int?.some(b.id))
                            }
                        }
                        .onChange(of: billID) { _, _ in Task { await loadBillDetail() } }
                    }
                } header: {
                    Text("Against bill (optional)")
                } footer: {
                    Text("Linking a bill reduces what you owe. Leave blank if you can't trace the original bill.")
                }
            }

            // ── Items ────────────────────────────────────────────
            if usingBill {
                Section {
                    if loadingBillDetail {
                        HStack {
                            ProgressView().tint(.sAccent)
                            Text("Loading bill items…").font(.subheadline).foregroundColor(.sMutedFG)
                        }
                    } else {
                        ForEach($billLines) { $l in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(l.line.item_name)
                                    .font(.subheadline.weight(.medium))
                                HStack {
                                    Text("\(l.line.qty) received at \(Money.text(l.line.rate))")
                                        .font(.footnote).foregroundColor(.sMutedFG)
                                    Spacer()
                                    TextField("0", text: $l.qty)
                                        .keyboardType(.numberPad)
                                        .multilineTextAlignment(.trailing)
                                        .frame(width: 60)
                                }
                                if (Int(l.qty) ?? 0) > l.line.qty {
                                    Text("Only \(l.line.qty) on this bill.")
                                        .font(.footnote).foregroundColor(.sDestructive)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Items going back")
                } footer: {
                    if total > 0 {
                        Text("\(Money.text(total)) will come off what you owe, and stock will leave your shelves.")
                    }
                }
            } else if supplierID != nil {
                Section {
                    ForEach($manualLines) { $l in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(l.item.name).font(.subheadline.weight(.medium))
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Qty").font(.caption).foregroundColor(.sMutedFG)
                                    TextField("0", text: $l.qty)
                                        .keyboardType(.numberPad)
                                        .frame(width: 56)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Rate").font(.caption).foregroundColor(.sMutedFG)
                                    TextField("0.00", text: $l.rate)
                                        .keyboardType(.decimalPad)
                                        .frame(width: 80)
                                }
                                Spacer()
                                let net = (Double(l.qty) ?? 0) * (Double(l.rate) ?? 0)
                                Text(Money.text(net + net * l.taxRate / 100))
                                    .font(.subheadline.weight(.medium))
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .onDelete { manualLines.remove(atOffsets: $0) }

                    Button {
                        showItemPicker = true
                    } label: {
                        Label("Add item", systemImage: "plus.circle")
                            .font(.body)
                            .foregroundColor(.sAccent)
                    }
                } header: {
                    Text("Items going back")
                } footer: {
                    if total > 0 {
                        Text("Total: \(Money.text(total)) · Stock will be reduced for each item.")
                    }
                }
            }
        }
        .navigationTitle("New debit note")
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
            DebitNoteItemPicker { item in
                if !manualLines.contains(where: { $0.item.id == item.id }) {
                    manualLines.append(ManualReturnLine(
                        item: item,
                        rate: item.cost_price != nil ? String(format: "%.2f", item.cost_price!) : ""
                    ))
                }
                showItemPicker = false
            }
        }
    }

    // MARK: - Data loading

    private func loadBills() async {
        guard let companyID = SessionManager.shared.selectedCompanyId,
              let sid = supplierID else { return }
        loadingBills = true
        defer { loadingBills = false }
        supplierBills = (try? await PurchasesService().bills(
            companyID: companyID, supplierID: sid, status: "owed"
        )) ?? []
    }

    private func loadBillDetail() async {
        guard let companyID = SessionManager.shared.selectedCompanyId,
              let bid = billID else {
            billDetail = nil; billLines = []; return
        }
        loadingBillDetail = true
        defer { loadingBillDetail = false }
        if let detail = try? await PurchasesService().billDetail(companyID: companyID, billID: bid) {
            billDetail = detail
            billLines = detail.items.map { BillReturnLine(line: $0) }
        }
    }

    // MARK: - Save

    private func save() {
        guard let sid = supplierID,
              let companyID = SessionManager.shared.selectedCompanyId else { return }

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let dateStr = df.string(from: returnDate)

        let items: [PurchaseReturnLineRequest]
        if usingBill {
            items = billLines.compactMap { l in
                guard let qty = Int(l.qty), qty > 0 else { return nil }
                return PurchaseReturnLineRequest(
                    item_id: l.line.item_id, qty: qty,
                    rate: l.line.rate, tax_rate: l.line.tax_rate
                )
            }
        } else {
            items = manualLines.compactMap { l in
                guard let qty = Int(l.qty), qty > 0,
                      let rate = Double(l.rate), rate > 0 else { return nil }
                return PurchaseReturnLineRequest(
                    item_id: l.item.id, qty: qty,
                    rate: rate, tax_rate: l.taxRate
                )
            }
        }
        guard !items.isEmpty else { return }

        let request = NewPurchaseReturnRequest(
            supplier_id: sid,
            bill_id: billID,
            return_number: returnNumber.trimmingCharacters(in: .whitespaces),
            return_date: dateStr,
            reason: reason.isEmpty ? nil : reason,
            notes: nil,
            items: items
        )

        Task {
            if await vm.recordReturn(request) { dismiss() }
        }
    }
}
