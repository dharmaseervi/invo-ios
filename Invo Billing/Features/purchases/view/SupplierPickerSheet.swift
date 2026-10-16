import SwiftUI

/// Supplier lookup stays searchable and paged even when a business has hundreds of accounts.
struct SupplierPickerSheet: View {
    @ObservedObject var purchasesVM: PurchasesViewModel
    var selectedID: Int?
    let onPick: (Supplier) -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: SessionManager
    @StateObject private var vm = PurchaseLedgerViewModel()
    @State private var search = ""
    @State private var showAddSupplier = false

    var body: some View {
        NavigationStack {
            List {
                if vm.isLoading && vm.suppliers.isEmpty {
                    ProgressView("Loading suppliers…")
                } else if let error = vm.loadError {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(error).foregroundStyle(.secondary)
                        Button("Retry") { Task { await reload() } }
                    }
                } else if vm.suppliers.isEmpty {
                    ContentUnavailableView.search(text: search)
                }
                ForEach(vm.suppliers) { supplier in
                    Button {
                        onPick(supplier)
                        dismiss()
                    } label: {
                        AdaptiveFormRow {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(supplier.name).font(.body).foregroundStyle(.primary)
                                if !supplier.phone.isEmpty { Text(supplier.phone).font(.footnote).foregroundStyle(.secondary) }
                                Text("Owed \(Money.text(supplier.due))").font(.footnote).foregroundStyle(.secondary)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                            if supplier.id == selectedID { Image(systemName: "checkmark").foregroundStyle(Color.sAccent) }
                        }
                    }
                    .accessibilityAddTraits(supplier.id == selectedID ? .isSelected : [])
                    .task {
                        if supplier.id == vm.suppliers.suffix(5).first?.id { await vm.loadMore() }
                    }
                }
                if vm.isLoadingMore { ProgressView("Loading more suppliers…") }
                else if vm.pageError != nil {
                    Button("Retry more suppliers") { Task { await vm.loadMore(retry: true) } }
                } else if vm.hasMore {
                    Button("Load more suppliers") { Task { await vm.loadMore() } }
                }
            }
            .navigationTitle("Choose supplier")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search, prompt: "Supplier name or phone")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button { showAddSupplier = true } label: { Label("Add supplier", systemImage: "plus") }
                }
            }
            .task(id: "\(session.selectedCompanyId ?? 0):\(search)") {
                await vm.load(companyID: session.selectedCompanyId, search: search, debounce: true)
            }
            .sheet(isPresented: $showAddSupplier, onDismiss: { Task { await reload() } }) {
                NavigationStack { AddSupplierSheet(vm: purchasesVM) }
            }
        }
    }

    private func reload() async { await vm.load(companyID: session.selectedCompanyId, search: search) }
}
