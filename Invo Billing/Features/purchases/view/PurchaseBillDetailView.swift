import SwiftUI

struct PurchaseBillDetailView: View {
    let bill: PurchaseBill

    @State private var detail: PurchaseBillDetail?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var returningBill: PurchaseBill?
    @State private var cancellingBill: PurchaseBill?
    @StateObject private var vm = PurchasesViewModel()

    var body: some View {
        ZStack {
            Color.sBackground.ignoresSafeArea()

            if isLoading {
                ProgressView().tint(.sAccent)
            } else if let error = errorMessage {
                VStack(spacing: 10) {
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.sMutedFG)
                        .multilineTextAlignment(.center)
                    Button("Try again") { Task { await load() } }
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.sAccent)
                }
                .padding(.horizontal, 32)
            } else if let d = detail {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        summaryCard(d)
                        if !d.items.isEmpty { itemsSection(d) }
                        if !d.notes.isEmpty { notesSection(d.notes) }
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, AppSpacing.page)
                    .padding(.top, 16)
                }
            }
        }
        .navigationTitle(bill.bill_number)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if !bill.isAmountOnly && !bill.isCancelled {
                        Button {
                            returningBill = bill
                        } label: {
                            Label("Create debit note", systemImage: "arrow.uturn.backward.circle")
                        }
                    }
                    if !bill.isCancelled {
                        Button(role: .destructive) {
                            cancellingBill = bill
                        } label: {
                            Label("Cancel bill", systemImage: "xmark.circle")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .disabled(bill.isCancelled && bill.isAmountOnly)
            }
        }
        .sheet(item: $returningBill) { b in
            NavigationStack { ReturnToSupplierSheet(bill: b, vm: vm) }
        }
        .alert("Cancel bill?", isPresented: Binding(
            get: { cancellingBill != nil },
            set: { if !$0 { cancellingBill = nil } }
        )) {
            Button("Cancel bill", role: .destructive) {
                guard let b = cancellingBill else { return }
                cancellingBill = nil
                Task { await cancelBill(id: b.id) }
            }
            Button("Keep it", role: .cancel) { cancellingBill = nil }
        } message: {
            if let b = cancellingBill {
                Text("This will void bill \(b.bill_number) and reverse its stock.")
            }
        }
        .task { await load() }
    }

    // MARK: - Cards

    private func summaryCard(_ d: PurchaseBillDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(d.supplier_name)
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.sForeground)
                    Text("Bill \(d.bill_number)")
                        .font(.subheadline)
                        .foregroundColor(.sMutedFG)
                }
                Spacer()
                statusPill
            }

            Divider()

            VStack(spacing: 8) {
                row("Bill date", AppDate.shortText(fromWire: d.bill_date))
                row("Due date", AppDate.shortText(fromWire: d.due_date))
                row("Subtotal", Money.text(d.subtotal))
                if d.tax > 0 { row("Tax", Money.text(d.tax)) }
                HStack {
                    Text("Total")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.sForeground)
                    Spacer()
                    Text(Money.text(d.total)).moneyLine()
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.sForeground)
                }
                if d.paid_amount > 0 { row("Paid", Money.text(d.paid_amount)) }
                if d.remaining_amount > 0 {
                    HStack {
                        Text("Still owing")
                            .font(.subheadline)
                            .foregroundColor(.sForeground)
                        Spacer()
                        Text(Money.text(d.remaining_amount)).moneyLine()
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(bill.isOverdue ? .sDestructive : .sMutedFG)
                    }
                }
            }
        }
        .padding(AppSpacing.card)
        .background(Color.sCard)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.sBorder, lineWidth: 0.5))
        .cornerRadius(16)
    }

    private func itemsSection(_ d: PurchaseBillDetail) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Items")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.sMutedFG)

            VStack(spacing: 8) {
                ForEach(d.items) { line in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(line.item_name)
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.sForeground)
                            Spacer()
                            Text(Money.text(line.total)).moneyLine()
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.sForeground)
                        }
                        HStack {
                            Text("\(line.qty) × \(Money.text(line.rate))")
                                .font(.footnote)
                                .foregroundColor(.sMutedFG)
                            if line.tax_rate > 0 {
                                Text("· \(line.tax_rate, specifier: "%.0f")% GST")
                                    .font(.footnote)
                                    .foregroundColor(.sMutedFG)
                            }
                            Spacer()
                        }
                    }
                    .padding(.vertical, 4)
                    if line.id != d.items.last?.id {
                        Divider()
                    }
                }
            }
            .padding(14)
            .background(Color.sCard)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.sBorder, lineWidth: 0.5))
            .cornerRadius(14)
        }
    }

    private func notesSection(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Notes")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.sMutedFG)
            Text(notes)
                .font(.subheadline)
                .foregroundColor(.sForeground)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.sCard)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.sBorder, lineWidth: 0.5))
                .cornerRadius(14)
        }
    }

    // MARK: - Helpers

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.sMutedFG)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundColor(.sForeground)
        }
    }

    private var statusPill: some View {
        let (label, colour): (String, Color) = {
            if bill.isOverdue  { return ("Overdue", .sDestructive) }
            switch bill.status {
            case "cancelled":   return ("Cancelled", .sMutedFG)
            case "paid":        return ("Paid", .sSuccess)
            case "partial":     return ("Part paid", .sAccent)
            default:            return ("Unpaid", .sMutedFG)
            }
        }()
        return Text(label)
            .font(.caption.weight(.medium))
            .foregroundColor(colour)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(colour.opacity(0.12))
            .cornerRadius(6)
    }

    // MARK: - Actions

    private func load() async {
        guard let companyID = SessionManager.shared.selectedCompanyId else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            detail = try await PurchasesService().billDetail(companyID: companyID, billID: bill.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func cancelBill(id: Int) async {
        guard let companyID = SessionManager.shared.selectedCompanyId else { return }
        do {
            try await PurchasesService().cancelBill(companyID: companyID, billID: id)
            await load()
        } catch {}
    }
}
