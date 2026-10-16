import SwiftUI

/// Standalone debit note creation — no bill required.
/// The user picks a supplier, optionally links a bill, and enters the items going back.
struct CreateDebitNoteSheet: View {
    @ObservedObject var vm: PurchasesViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var supplierID: Int?
    @State private var chosenSupplier: Supplier?
    @State private var showSupplierPicker = false
    @State private var confirmDiscard = false
    @State private var loadError: String?
    @State private var billsGeneration = 0
    @State private var detailGeneration = 0
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
        chosenSupplier ?? vm.suppliers.first { $0.id == supplierID }
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
              !vm.isWorking, !loadingBills, !loadingBillDetail, loadError == nil else { return false }
        if usingBill { return total > 0 && !overReturning }
        return !manualLines.isEmpty && manualLines.allSatisfy {
            (Int($0.qty) ?? 0) > 0 && (Double($0.rate) ?? 0) > 0
        }
    }

    private var isDirty: Bool {
        supplierID != nil || !returnNumber.isEmpty || !reason.isEmpty || !manualLines.isEmpty || billLines.contains { !$0.qty.isEmpty }
    }

    var body: some View {
        Form {
            // ── Supplier & document ──────────────────────────────
            Section("Debit note") {
                Button { showSupplierPicker = true } label: {
                    LabeledContent("Supplier", value: selectedSupplier?.name ?? "Choose supplier")
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
                    } else if let loadError {
                        Text(loadError).font(.footnote).foregroundStyle(Color.sDestructive)
                        Button("Retry bills") { Task { await loadBills() } }
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
                            AdaptiveFormRow {
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
        .protectUnsavedChanges(isDirty: isDirty, confirmDiscard: $confirmDiscard) { dismiss() }
        .sheet(isPresented: $showSupplierPicker) {
            SupplierPickerSheet(purchasesVM: vm, selectedID: supplierID) { supplier in
                chosenSupplier = supplier
                supplierID = supplier.id
            }
        }
        .navigationTitle("New debit note")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { if isDirty { confirmDiscard = true } else { dismiss() } }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") { save() }.disabled(!canSave)
            }
        }
        .sheet(isPresented: $showItemPicker) {
            PurchaseItemPicker { item in
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
        billsGeneration += 1
        let request = billsGeneration
        supplierBills = []
        loadError = nil
        loadingBills = true
        defer { if request == billsGeneration { loadingBills = false } }
        do {
            // A bill may be returned after it was paid. Include every non-cancelled,
            // itemised bill, fetching all pages for this optional picker.
            var offset = 0
            var all: [PurchaseBill] = []
            while true {
                let page = try await PurchasesService().bills(companyID: companyID, supplierID: sid, limit: 100, offset: offset)
                guard request == billsGeneration, supplierID == sid, !Task.isCancelled else { return }
                all += page.filter { !$0.isCancelled && !$0.isAmountOnly }
                offset += page.count
                if page.count < 100 { break }
            }
            supplierBills = all
        } catch {
            guard request == billsGeneration, supplierID == sid else { return }
            loadError = "Couldn't load this supplier's bills. Try again."
        }
    }

    private func loadBillDetail() async {
        guard let companyID = SessionManager.shared.selectedCompanyId,
              let bid = billID else {
            detailGeneration += 1
            loadingBillDetail = false
            billDetail = nil; billLines = []; return
        }
        detailGeneration += 1
        let request = detailGeneration
        billDetail = nil
        billLines = []
        loadError = nil
        loadingBillDetail = true
        defer { if request == detailGeneration { loadingBillDetail = false } }
        do {
            let detail = try await PurchasesService().billDetail(companyID: companyID, billID: bid)
            guard request == detailGeneration, billID == bid, !Task.isCancelled else { return }
            billDetail = detail
            billLines = detail.items.map { BillReturnLine(line: $0) }
        } catch {
            guard request == detailGeneration, billID == bid else { return }
            loadError = "Couldn't load bill items. Select the bill again to retry."
        }
    }

    // MARK: - Save

    private func save() {
        guard canSave, let sid = supplierID,
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
