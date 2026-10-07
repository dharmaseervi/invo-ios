//
//  PurchasesView.swift
//  Invo Billing
//
//  What the shop bought and what it owes for it.
//

import SwiftUI

struct PurchasesView: View {
    @StateObject private var vm = PurchasesViewModel()

    @State private var showAddSupplier = false
    @State private var showRecordBill = false
    @State private var payingSupplier: Supplier?
    @State private var returningBill: PurchaseBill?
    @State private var cancellingBill: PurchaseBill?

    var body: some View {
        ZStack {
            Color.sBackground.ignoresSafeArea()

            if vm.isLoading && vm.bills.isEmpty && vm.suppliers.isEmpty {
                ProgressView().tint(.sAccent)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        dueCard

                        if vm.suppliers.isEmpty {
                            emptyState
                        } else {
                            sectionHeader("Suppliers")
                            ForEach(vm.suppliers) { supplier in
                                supplierCard(supplier)
                            }


                            sectionHeader("Bills")
                            filterRow
                            if vm.bills.isEmpty {
                                Text("No bills here yet.")
                                    .font(.scaled(13))
                                    .foregroundColor(.sMutedFG)
                                    .padding(.vertical, 20)
                                    .frame(maxWidth: .infinity)
                            }
                            ForEach(vm.bills) { bill in
                                billCard(bill)
                                    .contextMenu {
                                        if !bill.isAmountOnly {
                                            Button {
                                                returningBill = bill
                                            } label: {
                                                Label("Return to supplier", systemImage: "arrow.uturn.backward")
                                            }
                                        }
                                        if !bill.isSettled {
                                            Button(role: .destructive) {
                                                cancellingBill = bill
                                            } label: {
                                                Label("Cancel bill", systemImage: "xmark.circle")
                                            }
                                        }
                                    }
                            }
                            if vm.isLoadingMoreBills {
                                ProgressView()
                            } else if let error = vm.pageError {
                                Text(error).foregroundColor(.sDestructive)
                                Button("Try again") { Task { await vm.loadMoreBills(retry: true) } }
                            } else if vm.hasMoreBills {
                                Button("Load more bills") { Task { await vm.loadMoreBills() } }
                            }

                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
                .refreshable { await vm.load() }
            }
        }
        .navigationTitle("Purchases")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showRecordBill = true
                    } label: {
                        Label("Record a bill", systemImage: "doc.text")
                    }
                    .disabled(vm.suppliers.isEmpty)

                    Button {
                        showAddSupplier = true
                    } label: {
                        Label("Add supplier", systemImage: "person.badge.plus")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .searchable(text: $vm.search, prompt: "Invoice number or supplier")
        .task(id: vm.search) {
            do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
            await vm.load()
        }
        .onChange(of: vm.billFilter) { _, _ in Task { await vm.load() } }
        .sheet(isPresented: $showAddSupplier) {
            NavigationStack { AddSupplierSheet(vm: vm) }
        }
        .sheet(isPresented: $showRecordBill) {
            NavigationStack { RecordPurchaseBillSheet(vm: vm) }
        }
        .sheet(item: $payingSupplier) { supplier in
            NavigationStack { PaySupplierSheet(supplier: supplier, vm: vm) }
        }
        .sheet(item: $returningBill) { bill in
            NavigationStack { ReturnToSupplierSheet(bill: bill, vm: vm) }
        }
        .alert("Cancel bill?", isPresented: Binding(
            get: { cancellingBill != nil },
            set: { if !$0 { cancellingBill = nil } }
        )) {
            Button("Cancel bill", role: .destructive) {
                guard let bill = cancellingBill else { return }
                cancellingBill = nil
                Task { await vm.cancelBill(id: bill.id) }
            }
            Button("Keep it", role: .cancel) { cancellingBill = nil }
        } message: {
            if let bill = cancellingBill {
                Text("This will void bill \(bill.bill_number) and reverse its stock. Any payments already applied to it will be kept as a supplier advance.")
            }
        }
        .alert("Purchases", isPresented: $vm.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.errorMessage ?? "Something went wrong")
        }
    }

    private var dueCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Owed to suppliers")
                .font(.scaled(13))
                .foregroundColor(.sMutedFG)

            if let due = vm.totalDue {
                Text(Money.text(due)).moneyLine()
                    .font(.scaled(26, weight: .bold))
                    .foregroundColor(due > 0 ? .sDestructive : Color(red: 0.086, green: 0.639, blue: 0.341))
                if vm.loadFailed {
                    // The figure is real but it is the one from before the failed
                    // refresh, and saying so is the difference between a stale number
                    // and a wrong one.
                    Text("Couldn't refresh — this may be out of date")
                        .font(.scaled(12))
                        .foregroundColor(.sDestructive)
                } else {
                    Text("Across \(vm.suppliers.filter { $0.due > 0 }.count) supplier\(vm.suppliers.filter { $0.due > 0 }.count == 1 ? "" : "s")")
                        .font(.scaled(12))
                        .foregroundColor(.sMutedFG)
                }
            } else {
                // Never loaded. A dash, not ₹0.00 — the shop is not being told it owes
                // nothing, it is being told we do not know.
                Text("—").moneyLine()
                    .font(.scaled(26, weight: .bold))
                    .foregroundColor(.sMutedFG)
                if vm.loadFailed {
                    Button("Try again") { Task { await vm.load() } }
                        .font(.scaled(12, weight: .medium))
                        .foregroundColor(.sAccent)
                } else {
                    Text("Loading…")
                        .font(.scaled(12))
                        .foregroundColor(.sMutedFG)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.sCard)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.sBorder, lineWidth: 0.5))
        .cornerRadius(16)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.scaled(13, weight: .medium))
            .foregroundColor(.sMutedFG)
            .padding(.top, 6)
    }

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterPill("All", nil)
                filterPill("Owed", "owed")
                filterPill("Overdue", "overdue")
                filterPill("Paid", "paid")
            }
        }
    }

    private func filterPill(_ label: String, _ value: String?) -> some View {
        let selected = vm.billFilter == value
        return Button {
            vm.billFilter = value
        } label: {
            Text(label)
                .font(.scaled(13, weight: selected ? .medium : .regular))
                .foregroundColor(selected ? .sForeground : .sMutedFG)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(selected ? Color.sCard : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(selected ? Color.sBorder : Color.clear, lineWidth: 0.5)
                )
                .cornerRadius(20)
        }
    }

    private func supplierCard(_ supplier: Supplier) -> some View {
        // The card opens their statement; Pay sits outside the link rather than inside
        // it, because a button nested in a NavigationLink can fire both at once — the
        // sheet opening on top of a screen that is already pushing.
        HStack(spacing: 10) {
            NavigationLink {
                SupplierStatementView(supplier: supplier)
            } label: {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(supplier.name)
                            .font(.scaled(14, weight: .medium))
                            .foregroundColor(.sForeground)
                        Text(supplierSubtitle(supplier))
                            .font(.scaled(12))
                            .foregroundColor(.sMutedFG)
                    }
                    Spacer()
                    Text(Money.text(supplier.due)).moneyLine()
                        .font(.scaled(14, weight: .semibold))
                        .foregroundColor(supplier.due > 0 ? .sDestructive : .sMutedFG)
                    Image(systemName: "chevron.right")
                        .font(.scaled(11, weight: .semibold))
                        .foregroundColor(.sMutedFG)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if supplier.due > 0 {
                Button("Pay") { payingSupplier = supplier }
                    .font(.scaled(13, weight: .medium))
                    .foregroundColor(.sAccent)
            }
        }
        .padding(14)
        .background(Color.sCard)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.sBorder, lineWidth: 0.5))
        .cornerRadius(14)
    }

    /// What is going on with this supplier, in one line. An advance is said out loud:
    /// a supplier owed nothing while holding the shop's deposit reads as "nothing
    /// owing" otherwise, and the money looks lost.
    private func supplierSubtitle(_ supplier: Supplier) -> String {
        if supplier.heldInAdvance > 0.004 {
            let advance = Money.text(supplier.heldInAdvance)
            return supplier.due > 0
                ? "\(supplier.open_bills) open bill\(supplier.open_bills == 1 ? "" : "s") · \(advance) paid ahead"
                : "\(advance) paid ahead"
        }
        return supplier.due > 0
            ? "\(supplier.open_bills) open bill\(supplier.open_bills == 1 ? "" : "s")"
            : "Nothing owing"
    }

    private func billCard(_ bill: PurchaseBill) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(bill.supplier_name)
                        .font(.scaled(14, weight: .medium))
                        .foregroundColor(.sForeground)
                    Text("\(bill.bill_number) · \(AppDate.shortText(fromWire: bill.bill_date))")
                        .font(.scaled(12))
                        .foregroundColor(.sMutedFG)
                    if bill.isAmountOnly {
                        Text("Amount only · No stock entry")
                            .font(.scaled(12))
                            .foregroundColor(.sMutedFG)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(Money.text(bill.total)).moneyLine()
                        .font(.scaled(14, weight: .semibold))
                        .foregroundColor(.sForeground)
                    statusPill(bill)
                }
            }

            if bill.remaining_amount > 0 {
                Text("\(Money.text(bill.remaining_amount)) still owing")
                    .font(.scaled(12))
                    .foregroundColor(bill.isOverdue ? .sDestructive : .sMutedFG)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.sCard)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.sBorder, lineWidth: 0.5))
        .cornerRadius(14)
    }

    private func statusPill(_ bill: PurchaseBill) -> some View {
        let (label, colour): (String, Color) = {
            if bill.isOverdue { return ("Overdue", .sDestructive) }
            switch bill.status {
            case "paid": return ("Paid", Color(red: 0.086, green: 0.639, blue: 0.341))
            case "partial": return ("Part paid", .sAccent)
            default: return ("Unpaid", .sMutedFG)
            }
        }()
        return Text(label)
            .font(.scaled(11, weight: .medium))
            .foregroundColor(colour)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(colour.opacity(0.12))
            .cornerRadius(6)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "shippingbox")
                .font(.scaled(30))
                .foregroundColor(.sMutedFG)
            Text("No suppliers yet")
                .font(.scaled(15, weight: .medium))
                .foregroundColor(.sForeground)
            Text("Add the people you buy from, then record an invoice amount or add the items you received.")
                .font(.scaled(12))
                .foregroundColor(.sMutedFG)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            Button("Add supplier") { showAddSupplier = true }
                .font(.scaled(14, weight: .medium))
                .foregroundColor(.sAccent)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
