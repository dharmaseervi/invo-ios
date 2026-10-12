import Combine
import SwiftUI

struct SupplierDetailView: View {
    let supplier: Supplier

    @StateObject private var vm = SupplierDetailViewModel()
    @State private var showPay = false
    @State private var showDebitNote = false
    @State private var showStatement = false
    @State private var showEdit = false
    @State private var returningBill: PurchaseBill?
    @State private var cancellingBill: PurchaseBill?

    /// The supplier as last loaded — the value passed in goes stale the moment a payment,
    /// return or cancellation is made from this screen.
    private var current: Supplier {
        vm.purchasesVM.suppliers.first { $0.id == supplier.id } ?? supplier
    }

    private func reload() async { await vm.load(supplier: supplier) }

    var body: some View {
        List {
            VStack(spacing: 12) {
                infoCard
                actionRow
            }
            .padding(.horizontal, AppSpacing.page)
            .padding(.top, 8)
            .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            filterRow
                .padding(.vertical, 8)
                .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            billsSection
        }
        .listStyle(.plain)
        .contentMargins(.bottom, 16, for: .scrollContent)
        .refreshable { await reload() }
        .navigationTitle(current.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { showStatement = true } label: {
                        Label("Statement PDF", systemImage: "doc.text")
                    }
                    Button { showEdit = true } label: {
                        Label("Edit supplier", systemImage: "pencil")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showPay, onDismiss: { Task { await reload() } }) {
            NavigationStack { PaySupplierSheet(supplier: current, vm: vm.purchasesVM) }
        }
        .sheet(isPresented: $showDebitNote, onDismiss: { Task { await reload() } }) {
            NavigationStack { CreateDebitNoteSheet(vm: vm.purchasesVM) }
        }
        .sheet(isPresented: $showStatement) {
            NavigationStack { SupplierStatementShareView(supplier: supplier) }
        }
        .sheet(isPresented: $showEdit, onDismiss: { Task { await reload() } }) {
            NavigationStack {
                EditSupplierSheet(
                    supplier: current,
                    vm: vm.purchasesVM
                )
            }
        }
        .sheet(item: $returningBill, onDismiss: { Task { await reload() } }) { bill in
            NavigationStack { ReturnToSupplierSheet(bill: bill, vm: vm.purchasesVM) }
        }
        .alert("Cancel bill?", isPresented: Binding(
            get: { cancellingBill != nil },
            set: { if !$0 { cancellingBill = nil } }
        )) {
            Button("Cancel bill", role: .destructive) {
                guard let bill = cancellingBill else { return }
                cancellingBill = nil
                Task {
                    await vm.cancelBill(id: bill.id)
                    await reload()
                }
            }
            Button("Keep it", role: .cancel) { cancellingBill = nil }
        } message: {
            if let bill = cancellingBill {
                Text("This will void bill \(bill.bill_number) and reverse its stock.")
            }
        }
        .alert("Error", isPresented: $vm.showError) {
            Button("OK", role: .cancel) {}
        } message: { Text(vm.errorMessage ?? "") }
        .task { await reload() }
    }

    // MARK: - Supplier info card

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(current.due > 0 ? "Owed" : current.heldInAdvance > 0 ? "Paid in advance" : "Settled")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(Money.text(current.due > 0 ? current.due : current.heldInAdvance)).moneyLine()
                    .font(.title.bold())
                    .foregroundStyle(current.due > 0 ? Color.sDestructive : Color.sSuccess)
                let place = [current.city,
                             current.open_bills > 0 ? "\(current.open_bills) open bill\(current.open_bills == 1 ? "" : "s")" : ""]
                    .filter { !$0.isEmpty }
                    .joined(separator: " · ")
                if !place.isEmpty {
                    Text(place)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if !current.phone.isEmpty || !current.email.isEmpty || !current.gstin.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    if !current.phone.isEmpty {
                        infoRow(icon: "phone", text: current.phone)
                    }
                    if !current.email.isEmpty {
                        infoRow(icon: "envelope", text: current.email)
                    }
                    if !current.gstin.isEmpty {
                        infoRow(icon: "doc.badge.gearshape", text: "GSTIN: \(current.gstin)")
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func infoRow(icon: String, text: String) -> some View {
        Label {
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
        } icon: {
            Image(systemName: icon)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Action buttons

    private var actionRow: some View {
        HStack(spacing: 8) {
            if current.due > 0 {
                Button { showPay = true } label: {
                    Label("Pay", systemImage: "indianrupeesign.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            Button { showDebitNote = true } label: {
                Label("Debit note", systemImage: "arrow.uturn.backward.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            Button { showStatement = true } label: {
                Label("Statement", systemImage: "list.bullet.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .font(.footnote.weight(.semibold))
        .labelStyle(.titleOnly)
        .controlSize(.regular)
        .tint(.sAccent)
    }

    // MARK: - Bills section

    @ViewBuilder
    private var billsSection: some View {
        if vm.isLoading {
            HStack { Spacer(); ProgressView().tint(.sAccent); Spacer() }
                .padding(.vertical, 20)
                .listRowSeparator(.hidden)
        } else if vm.bills.isEmpty {
            Text("No bills yet for this supplier.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 24)
                .listRowSeparator(.hidden)
        } else {
            ForEach(vm.bills) { bill in
                NavigationLink {
                    PurchaseBillDetailView(bill: bill)
                } label: {
                    billRow(bill)
                }
                .standardListRow()
                .listRowSeparator(.hidden, edges: bill.id == vm.bills.first?.id ? .top : [])
                .contextMenu {
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
                }
            }
        }
    }

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.inline) {
                filterPill("All bills", nil)
                filterPill("Owed", "owed")
                filterPill("Overdue", "overdue")
                filterPill("Paid", "paid")
            }
            .padding(.horizontal, AppSpacing.page)
        }
    }

    private func filterPill(_ label: String, _ value: String?) -> some View {
        AppFilterChip(title: label, isSelected: vm.filter == value) {
            vm.filter = value
            Task { await vm.load(supplier: supplier) }
        }
    }

    private func billRow(_ bill: PurchaseBill) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(bill.bill_number)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                HStack(spacing: 0) {
                    Text(AppDate.shortText(fromWire: bill.bill_date))
                        .foregroundStyle(.secondary)
                    if bill.remaining_amount > 0 {
                        Text(" · \(Money.text(bill.remaining_amount)) owing")
                            .foregroundStyle(bill.isOverdue ? Color.sDestructive : .secondary)
                    }
                }
                .font(.footnote)
                .lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 3) {
                Text(Money.text(bill.total)).moneyLine()
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                statusPill(bill)
            }
            .frame(minWidth: 88, alignment: .trailing)
        }
    }

    private func statusPill(_ bill: PurchaseBill) -> some View {
        let (label, colour): (String, Color) = {
            if bill.isOverdue { return ("Overdue", .sDestructive) }
            switch bill.status {
            case "cancelled": return ("Cancelled", .sMutedFG)
            case "paid":      return ("Paid", .sSuccess)
            case "partial":   return ("Part paid", .sAccent)
            default:          return ("Unpaid", .sMutedFG)
            }
        }()
        return Text(label)
            .font(.caption.weight(.medium))
            .foregroundColor(colour)
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(colour.opacity(0.1), in: Capsule())
    }
}

// MARK: - ViewModel

@MainActor
final class SupplierDetailViewModel: ObservableObject {
    @Published private(set) var bills: [PurchaseBill] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var filter: String?

    let purchasesVM = PurchasesViewModel()
    private let service = PurchasesService()

    func load(supplier: Supplier) async {
        guard let companyID = SessionManager.shared.selectedCompanyId else { return }
        isLoading = true
        defer { isLoading = false }
        // The supplier's owed / advance figures come from the suppliers list, refreshed
        // alongside the bills so the card and the bills never disagree.
        async let totals: Void = purchasesVM.load()
        do {
            bills = try await service.bills(companyID: companyID, supplierID: supplier.id, status: filter)
            await totals
        } catch {
            await totals
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func cancelBill(id: Int) async {
        guard let companyID = SessionManager.shared.selectedCompanyId else { return }
        do {
            try await service.cancelBill(companyID: companyID, billID: id)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
