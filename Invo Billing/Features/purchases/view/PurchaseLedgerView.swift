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
                        .standardListRow()
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
        .listStyle(.plain)
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
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(supplier.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text([supplier.phone,
                      "\(supplier.open_bills) unpaid bill\(supplier.open_bills == 1 ? "" : "s")"]
                        .filter { !$0.isEmpty }
                        .joined(separator: " · "))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 3) {
                if supplier.due > 0 {
                    Text(Money.text(supplier.due)).moneyLine()
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                } else if supplier.heldInAdvance <= 0 {
                    Text("Settled")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                if supplier.heldInAdvance > 0 {
                    Text("\(Money.text(supplier.heldInAdvance)) paid ahead")
                        .font(.caption)
                        .foregroundStyle(Color.sAccent)
                } else if supplier.due > 0 {
                    Text("Owed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(minWidth: 88, alignment: .trailing)
        }
    }
}
