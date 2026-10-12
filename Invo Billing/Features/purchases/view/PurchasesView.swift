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
                        .listHeaderRow()

                    if vm.suppliers.isEmpty {
                        emptyState
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    } else {
                        Section {
                            ForEach(vm.suppliers) { supplier in
                                supplierRow(supplier)
                                    .standardListRow()
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
                                        .standardListRow()
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
        // Never loaded: a dash, not ₹0.00 — the shop is not being told it owes nothing,
        // it is being told we do not know.
        SummaryCard(
            title: "Owed to suppliers",
            value: vm.totalDue.map { Money.text($0) } ?? "—",
            valueColor: vm.totalDue.map { $0 > 0 ? Color.sDestructive : Color.sSuccess } ?? .sMutedFG
        ) {
            if vm.totalDue != nil && vm.loadFailed {
                // The figure is real but it is the one from before the failed refresh,
                // and saying so is the difference between a stale number and a wrong one.
                Text("Couldn't refresh — this may be out of date")
                    .font(.footnote)
                    .foregroundStyle(Color.sDestructive)
            } else if vm.totalDue != nil {
                let owing = vm.suppliers.filter { $0.due > 0 }.count
                Text("Across \(owing) supplier\(owing == 1 ? "" : "s")")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if vm.loadFailed {
                Button("Try again") { Task { await vm.load() } }
                    .font(.footnote.weight(.medium))
                    .tint(Color.sAccent)
            } else {
                Text("Loading…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

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

                Text(Money.text(supplier.due)).moneyLine()
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(supplier.due > 0 ? Color.sDestructive : .secondary)
                    .frame(minWidth: 72, alignment: .trailing)

                // Its own control beside the amount, with a full 44pt target, so a tap
                // pays rather than opening the statement. Borderless keeps it from also
                // firing the row's NavigationLink.
                if supplier.due > 0 {
                    Button { payingSupplier = supplier } label: {
                        Text("Pay")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .frame(minHeight: AppSpacing.minimumTarget)
                            .background(Color.sAccent.opacity(0.12), in: Capsule())
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(Color.sAccent)
                    .accessibilityLabel("Pay \(supplier.name)")
                }
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
