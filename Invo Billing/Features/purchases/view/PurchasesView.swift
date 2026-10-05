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

    var body: some View {
        ZStack {
            Color.sBackground.ignoresSafeArea()

            if vm.isLoading && vm.bills.isEmpty && vm.suppliers.isEmpty {
                ProgressView().tint(.sAccent)
            } else {
                ScrollView {
                    // A plain stack, not a lazy one. Inside a LazyVStack the bill rows
                    // were built but never laid out when they arrived after the first
                    // render: the list stayed blank with the data sitting in it. The
                    // server caps this list at 50 rows, so there is nothing to gain from
                    // being lazy and a working screen to lose.
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
        .task { await vm.load() }
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
            Text(Money.text(vm.totalDue)).moneyLine()
                .font(.scaled(26, weight: .bold))
                .foregroundColor(vm.totalDue > 0 ? .sDestructive : Color(red: 0.086, green: 0.639, blue: 0.341))
            Text("Across \(vm.suppliers.filter { $0.due > 0 }.count) supplier\(vm.suppliers.filter { $0.due > 0 }.count == 1 ? "" : "s")")
                .font(.scaled(12))
                .foregroundColor(.sMutedFG)
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
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(supplier.name)
                    .font(.scaled(14, weight: .medium))
                    .foregroundColor(.sForeground)
                Text(supplier.due > 0
                     ? "\(supplier.open_bills) open bill\(supplier.open_bills == 1 ? "" : "s")"
                     : "Nothing owing")
                    .font(.scaled(12))
                    .foregroundColor(.sMutedFG)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(Money.text(supplier.due)).moneyLine()
                    .font(.scaled(14, weight: .semibold))
                    .foregroundColor(supplier.due > 0 ? .sDestructive : .sMutedFG)
                if supplier.due > 0 {
                    Button("Pay") { payingSupplier = supplier }
                        .font(.scaled(13, weight: .medium))
                        .foregroundColor(.sAccent)
                }
            }
        }
        .padding(14)
        .background(Color.sCard)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.sBorder, lineWidth: 0.5))
        .cornerRadius(14)
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
            Text("Add the people you buy from, then record their bills — stock and cost prices update as you do.")
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
