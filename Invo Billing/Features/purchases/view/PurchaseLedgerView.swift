import SwiftUI

/// A separate entry from More for finding a supplier's account. Purchases remains
/// the place to enter bills, stock and payments.
struct PurchaseLedgerView: View {
    @EnvironmentObject private var session: SessionManager
    @StateObject private var vm = PurchaseLedgerViewModel()
    @State private var search = ""

    private struct Query: Hashable {
        let companyID: Int?
        let search: String
    }

    private var query: Query {
        Query(companyID: session.selectedCompanyId, search: search)
    }

    var body: some View {
        List {
            if vm.isLoading {
                HStack(spacing: 12) {
                    ProgressView().tint(.sAccent)
                    Text("Loading suppliers…").foregroundColor(.sMutedFG)
                }
            } else if let error = vm.loadError {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Couldn't load suppliers").font(.headline)
                    Text(error).foregroundColor(.sMutedFG)
                    Button("Try again") { Task { await reload() } }
                }
                .padding(.vertical, 12)
            } else if vm.suppliers.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text(search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                         ? "No suppliers yet" : "No matching suppliers")
                        .font(.headline)
                    Text("Search by supplier name or phone number. Add suppliers and record bills in Purchases.")
                        .foregroundColor(.sMutedFG)
                    NavigationLink("Open purchases") { PurchasesView() }
                }
                .padding(.vertical, 12)
            } else {
                Section {
                    ForEach(vm.suppliers) { supplier in
                        NavigationLink {
                            SupplierStatementView(supplier: supplier)
                        } label: {
                            supplierRow(supplier)
                        }
                        .task {
                            if supplier.id == vm.suppliers.suffix(5).first?.id {
                                await vm.loadMore()
                            }
                        }
                    }
                } header: {
                    Text("Suppliers")
                } footer: {
                    Text("Open a supplier to see bills, payments, returns and the running balance.")
                }

                if vm.isLoadingMore {
                    ProgressView().tint(.sAccent)
                        .frame(maxWidth: .infinity)
                } else if let error = vm.pageError {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Couldn't load more suppliers").font(.headline)
                        Text(error).foregroundColor(.sMutedFG)
                        Button("Try again") { Task { await vm.loadMore(retry: true) } }
                    }
                } else if vm.hasMore {
                    Button("Load more suppliers") { Task { await vm.loadMore() } }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.sBackground)
        .navigationTitle("Purchase ledger")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Supplier name or phone")
        .task(id: query) {
            await vm.load(companyID: query.companyID, search: query.search, debounce: true)
        }
        .refreshable { await reload() }
    }

    private func reload() async {
        await vm.load(companyID: session.selectedCompanyId, search: search)
    }

    private func supplierRow(_ supplier: Supplier) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(supplier.name)
                    .font(.scaled(16, weight: .medium))
                    .foregroundColor(.sForeground)
                if !supplier.phone.isEmpty {
                    Text(supplier.phone)
                        .font(.scaled(13))
                        .foregroundColor(.sMutedFG)
                }
                Text("\(supplier.open_bills) unpaid bill\(supplier.open_bills == 1 ? "" : "s")")
                    .font(.scaled(12))
                    .foregroundColor(.sMutedFG)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 5) {
                if supplier.due > 0 {
                    Text(Money.text(supplier.due)).moneyLine()
                        .font(.scaled(16, weight: .semibold))
                        .foregroundColor(.sForeground)
                    Text("Owed to supplier")
                        .font(.scaled(12))
                        .foregroundColor(.sMutedFG)
                }
                if supplier.heldInAdvance > 0 {
                    Text("\(Money.text(supplier.heldInAdvance)) paid ahead")
                        .font(.scaled(12))
                        .foregroundColor(.sAccent)
                } else if supplier.due == 0 {
                    Text("Settled")
                        .font(.scaled(13, weight: .medium))
                        .foregroundColor(.sMutedFG)
                }
            }
        }
        .padding(.vertical, 6)
    }
}
