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
    @State private var showCreateDebitNote = false
    @State private var payingSupplier: Supplier?
    @State private var debitNotePDFURL: DebitNoteURLWrapper?
    @State private var isLoadingDebitNote = false

    var body: some View {
        Group {
            if vm.isLoading && vm.suppliers.isEmpty {
                ProgressView()
                    .tint(.sAccent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    dueCard
                        .padding(.horizontal, AppSpacing.page)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                        .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)

                    if vm.suppliers.isEmpty {
                        emptyState
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    } else {
                        Section {
                            ForEach(vm.suppliers) { supplier in
                                supplierRow(supplier)
                                    .listRowInsets(rowInsets)
                                    .swipeActions(edge: .trailing) {
                                        if supplier.due > 0 {
                                            Button("Pay") { payingSupplier = supplier }
                                                .tint(.sAccent)
                                        }
                                    }
                            }
                        } header: {
                            Text("Suppliers")
                        }

                        if !vm.returns.isEmpty {
                            Section {
                                ForEach(vm.returns) { ret in
                                    returnRow(ret)
                                        .listRowInsets(rowInsets)
                                        .contextMenu {
                                            Button {
                                                fetchDebitNote(ret)
                                            } label: {
                                                Label("View debit note", systemImage: "doc.text")
                                            }
                                        }
                                }
                            } header: {
                                Text("Returns")
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .contentMargins(.bottom, 16, for: .scrollContent)
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
                        showCreateDebitNote = true
                    } label: {
                        Label("New debit note", systemImage: "arrow.uturn.backward.circle")
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
        .sheet(isPresented: $showCreateDebitNote) {
            NavigationStack { CreateDebitNoteSheet(vm: vm) }
        }
        .alert("Purchases", isPresented: $vm.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.errorMessage ?? "Something went wrong")
        }
        .sheet(item: $debitNotePDFURL) { wrapper in
            NavigationStack { PDFLookView(pdfURL: wrapper.url) }
        }
        .overlay {
            if isLoadingDebitNote {
                ZStack {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    VStack(spacing: 10) {
                        ProgressView().tint(.white)
                        Text("Generating debit note…")
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                    .padding(24)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(14)
                }
            }
        }
    }

    private func fetchDebitNote(_ ret: PurchaseReturn) {
        guard let companyID = SessionManager.shared.selectedCompanyId else { return }
        isLoadingDebitNote = true
        Task {
            defer { isLoadingDebitNote = false }
            do {
                let url = try await PurchasesService().debitNotePDF(companyID: companyID, returnID: ret.id)
                debitNotePDFURL = DebitNoteURLWrapper(url: url)
            } catch {
                vm.errorMessage = "Could not load debit note PDF"
                vm.showError = true
            }
        }
    }

    private var dueCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Owed to suppliers")
                .font(.subheadline)
                .foregroundColor(.sMutedFG)

            if let due = vm.totalDue {
                Text(Money.text(due)).moneyLine()
                    .font(.title.bold())
                    .foregroundColor(due > 0 ? .sDestructive : .sSuccess)
                if vm.loadFailed {
                    // The figure is real but it is the one from before the failed
                    // refresh, and saying so is the difference between a stale number
                    // and a wrong one.
                    Text("Couldn't refresh — this may be out of date")
                        .font(.footnote)
                        .foregroundColor(.sDestructive)
                } else {
                    Text("Across \(vm.suppliers.filter { $0.due > 0 }.count) supplier\(vm.suppliers.filter { $0.due > 0 }.count == 1 ? "" : "s")")
                        .font(.footnote)
                        .foregroundColor(.sMutedFG)
                }
            } else {
                // Never loaded. A dash, not ₹0.00 — the shop is not being told it owes
                // nothing, it is being told we do not know.
                Text("—").moneyLine()
                    .font(.title.bold())
                    .foregroundColor(.sMutedFG)
                if vm.loadFailed {
                    Button("Try again") { Task { await vm.load() } }
                        .font(.footnote.weight(.medium))
                        .foregroundColor(.sAccent)
                } else {
                    Text("Loading…")
                        .font(.footnote)
                        .foregroundColor(.sMutedFG)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var rowInsets: EdgeInsets { EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20) }

    private func supplierRow(_ supplier: Supplier) -> some View {
        NavigationLink {
            SupplierDetailView(supplier: supplier)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(supplier.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(supplierSubtitle(supplier))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 3) {
                    Text(Money.text(supplier.due)).moneyLine()
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(supplier.due > 0 ? Color.sDestructive : .secondary)
                    // Borderless so a tap here pays rather than also opening the statement.
                    if supplier.due > 0 {
                        Button("Pay") { payingSupplier = supplier }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.sAccent)
                            .buttonStyle(.borderless)
                    }
                }
                .frame(minWidth: 88, alignment: .trailing)
            }
        }
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

    private func returnRow(_ ret: PurchaseReturn) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(ret.supplier_name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text("\(ret.return_number) · \(AppDate.shortText(fromWire: ret.return_date))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                let detail = [ret.bill_number.isEmpty ? "" : "Bill \(ret.bill_number)", ret.reason]
                    .filter { !$0.isEmpty }
                    .joined(separator: " · ")
                if !detail.isEmpty {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            Text(Money.text(ret.total)).moneyLine()
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.sDestructive)
                .frame(minWidth: 88, alignment: .trailing)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No suppliers yet", systemImage: "shippingbox")
        } description: {
            Text("Add the people you buy from, then record an invoice amount or add the items you received.")
        } actions: {
            Button("Add supplier") { showAddSupplier = true }
                .buttonStyle(.borderedProminent)
                .tint(.sAccent)
        }
        .padding(.vertical, 24)
    }
}

private struct DebitNoteURLWrapper: Identifiable {
    let id = UUID()
    let url: URL
}
