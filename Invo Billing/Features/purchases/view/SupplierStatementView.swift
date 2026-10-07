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
        ZStack {
            Color.sBackground.ignoresSafeArea()

            if vm.isLoading && vm.entries.isEmpty {
                ProgressView().tint(.sAccent)
            } else {
                ScrollView {
                    // A plain stack. The same list inside a LazyVStack built its rows
                    // and never laid them out when they arrived after the first render,
                    // and a statement page is 40 rows at most.
                    VStack(alignment: .leading, spacing: 0) {
                        balanceCard
                            .padding(.horizontal, 20)
                            .padding(.top, 16)

                        if vm.entries.isEmpty {
                            emptyState
                        } else {
                            if vm.isLoadingEarlier {
                                ProgressView()
                                    .tint(.sAccent)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                            } else if vm.hasMore {
                                Button("Load earlier entries") {
                                    Task { await vm.loadEarlier() }
                                }
                                .font(.scaled(13, weight: .medium))
                                .foregroundColor(.sAccent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                            }

                            VStack(spacing: 10) {
                                ForEach(vm.entries, id: \.rowKey) { entry in
                                    entryRow(entry)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 14)
                        }

                        Spacer(minLength: 40)
                    }
                }
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
                .font(.scaled(13))
                .foregroundColor(.sMutedFG)

            if let balance = vm.balance {
                Text(Money.text(abs(balance))).moneyLine()
                    .font(.scaled(26, weight: .bold))
                    .foregroundColor(
                        balance > 0.004
                            ? .sDestructive
                            : Color(red: 0.086, green: 0.639, blue: 0.341)
                    )
            } else {
                // Not known rather than nothing owed.
                Text("—").moneyLine()
                    .font(.scaled(26, weight: .bold))
                    .foregroundColor(.sMutedFG)
            }

            if vm.loadFailed {
                Text(vm.summary == nil ? "Totals unavailable" : "Couldn't refresh — figures may be out of date")
                    .font(.scaled(12))
                    .foregroundColor(.sDestructive)
                Button("Try again") { Task { await vm.load() } }
            }

            if let summary = vm.summary {
                Text("\(Money.text(summary.billed)) billed · \(Money.text(summary.paid)) paid")
                    .font(.scaled(12))
                    .foregroundColor(.sMutedFG)
            } else if !vm.isLoading && !vm.loadFailed {
                Button("Try again") { Task { await vm.load() } }
                    .font(.scaled(12, weight: .medium))
                    .foregroundColor(.sAccent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.sCard)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.sBorder, lineWidth: 0.5))
        .cornerRadius(16)
    }

    private func entryRow(_ entry: SupplierLedgerEntry) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: entry.isBill ? "doc.text" : "indianrupeesign.circle")
                .font(.scaled(15))
                .foregroundColor(entry.isBill ? .sMutedFG : Color(red: 0.086, green: 0.639, blue: 0.341))
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.description)
                    .font(.scaled(14, weight: .medium))
                    .foregroundColor(.sForeground)
                Text(AppDate.text(fromWire: entry.date))
                    .font(.scaled(12))
                    .foregroundColor(.sMutedFG)
                if !entry.reference.isEmpty && !entry.isBill {
                    Text(entry.reference)
                        .font(.scaled(12))
                        .foregroundColor(.sMutedFG)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                // A bill adds to what is owed, a payment takes it away, and the sign
                // says which without needing the words.
                Text((entry.isBill ? "+" : "−") + Money.text(entry.isBill ? entry.debit : entry.credit))
                    .moneyLine()
                    .font(.scaled(14, weight: .semibold))
                    .foregroundColor(entry.isBill ? .sForeground : Color(red: 0.086, green: 0.639, blue: 0.341))

                Text(balanceLabel(entry.balance))
                    .font(.scaled(11))
                    .foregroundColor(.sMutedFG)
            }
        }
        .padding(14)
        .background(Color.sCard)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.sBorder, lineWidth: 0.5))
        .cornerRadius(14)
    }

    /// The balance after a line, said the way it would be read aloud.
    private func balanceLabel(_ value: Double) -> String {
        if value > 0.004 { return "\(Money.text(value)) owed" }
        if value < -0.004 { return "\(Money.text(abs(value))) ahead" }
        return "settled"
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.scaled(28))
                .foregroundColor(.sMutedFG)
            Text("Nothing on this account yet")
                .font(.scaled(15, weight: .medium))
                .foregroundColor(.sForeground)
            Text("Record a bill from \(supplier.name) and it will show here, with every payment against it.")
                .font(.scaled(12))
                .foregroundColor(.sMutedFG)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
    }
}
