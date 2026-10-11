//
//  SupplierStatementView.swift
//  Invo Billing
//
//  A supplier's account: their bills, what has been paid against them, and the running
//  balance — the thing a shopkeeper holds next to the statement the supplier sends.
//

import SwiftUI

struct SupplierStatementView: View {
    let supplier: Supplier

    @StateObject private var vm: SupplierStatementViewModel
    @StateObject private var purchasesVM = PurchasesViewModel()
    @State private var showStatement = false
    @State private var showEdit = false

    init(supplier: Supplier) {
        self.supplier = supplier
        _vm = StateObject(wrappedValue: SupplierStatementViewModel(supplierID: supplier.id))
    }

    var body: some View {
        Group {
            if vm.isLoading && vm.entries.isEmpty {
                ProgressView()
                    .tint(.sAccent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    balanceCard
                        .padding(.horizontal, AppSpacing.page)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                        .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)

                    if vm.entries.isEmpty {
                        ContentUnavailableView(
                            "Nothing on this account yet",
                            systemImage: "doc.text.magnifyingglass",
                            description: Text("Record a bill from \(supplier.name) and it will show here, with every payment against it.")
                        )
                        .padding(.vertical, 24)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    } else {
                        if vm.isLoadingEarlier {
                            HStack { Spacer(); ProgressView().tint(.sAccent); Spacer() }
                                .padding(.vertical, 4)
                                .listRowSeparator(.hidden)
                        } else if vm.hasMore {
                            Button("Load earlier entries") {
                                Task { await vm.loadEarlier() }
                            }
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.sAccent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                            .listRowSeparator(.hidden)
                        }

                        ForEach(vm.entries, id: \.rowKey) { entry in
                            entryRow(entry)
                                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                                .listRowSeparator(.hidden, edges: entry.rowKey == vm.entries.first?.rowKey ? .top : [])
                        }
                    }
                }
                .listStyle(.plain)
                .contentMargins(.bottom, 16, for: .scrollContent)
                .refreshable { await vm.load() }
            }
        }
        .navigationTitle(vm.summary?.name ?? supplier.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showStatement = true
                    } label: {
                        Label("Statement PDF", systemImage: "doc.text")
                    }
                    Button {
                        showEdit = true
                    } label: {
                        Label("Edit supplier", systemImage: "pencil")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showStatement) {
            NavigationStack { SupplierStatementShareView(supplier: supplier) }
        }
        .sheet(isPresented: $showEdit, onDismiss: { Task { await vm.load() } }) {
            NavigationStack { EditSupplierSheet(supplier: purchasesVM.suppliers.first(where: { $0.id == supplier.id }) ?? supplier, vm: purchasesVM) }
        }
        .task { await vm.load() }
        .alert("Statement", isPresented: $vm.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.errorMessage ?? "Something went wrong")
        }
    }

    /// Where the account stands, and the two totals behind it. Worded rather than
    /// signed: "owed to them" and "paid ahead" are read correctly at a glance, where a
    /// minus sign in front of a rupee figure is not.
    private var balanceCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(vm.isInCredit ? "Paid ahead" : "Owed to them")
                .font(.subheadline)
                .foregroundColor(.sMutedFG)

            if let balance = vm.balance {
                Text(Money.text(abs(balance))).moneyLine()
                    .font(.title.bold())
                    .foregroundColor(
                        balance > 0.004
                            ? .sDestructive
                            : .sSuccess
                    )
            } else {
                // Not known rather than nothing owed.
                Text("—").moneyLine()
                    .font(.title.bold())
                    .foregroundColor(.sMutedFG)
            }

            if vm.loadFailed {
                Text(vm.summary == nil ? "Totals unavailable" : "Couldn't refresh — figures may be out of date")
                    .font(.footnote)
                    .foregroundColor(.sDestructive)
                Button("Try again") { Task { await vm.load() } }
            }

            if let summary = vm.summary {
                Text("\(Money.text(summary.billed)) billed · \(Money.text(summary.paid)) paid")
                    .font(.footnote)
                    .foregroundColor(.sMutedFG)
            } else if !vm.isLoading && !vm.loadFailed {
                Button("Try again") { Task { await vm.load() } }
                    .font(.footnote.weight(.medium))
                    .foregroundColor(.sAccent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func entryRow(_ entry: SupplierLedgerEntry) -> some View {
        let detail = [AppDate.text(fromWire: entry.date),
                      (!entry.reference.isEmpty && !entry.isBill) ? entry.reference : ""]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")

        return HStack(spacing: 12) {
            Image(systemName: entry.isBill ? "doc.text" : "indianrupeesign.circle")
                .font(.body)
                .foregroundStyle(entry.isBill ? Color.sAccent : Color.sSuccess)
                .frame(width: 40, height: 40)
                .background((entry.isBill ? Color.sAccent : Color.sSuccess).opacity(0.12), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.description)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .alignmentGuide(.listRowSeparatorLeading) { d in d[.leading] }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                // A bill adds to what is owed, a payment takes it away, and the sign
                // says which without needing the words.
                Text((entry.isBill ? "+" : "−") + Money.text(entry.isBill ? entry.debit : entry.credit))
                    .moneyLine()
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(entry.isBill ? Color.sForeground : Color.sSuccess)

                Text(balanceLabel(entry.balance))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(minWidth: 88, alignment: .trailing)
        }
    }

    /// The balance after a line, said the way it would be read aloud.
    private func balanceLabel(_ value: Double) -> String {
        if value > 0.004 { return "\(Money.text(value)) owed" }
        if value < -0.004 { return "\(Money.text(abs(value))) ahead" }
        return "settled"
    }
}
