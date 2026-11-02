import SwiftUI

struct SelectItemSheet: View {
    @Binding var selectedItems: [InvoiceLineItem]
    @Environment(\.dismiss) var dismiss

    @StateObject var vm = ItemViewModel()
    @State private var searchText = ""
    @State private var showAddItem = false
    @State private var showBarcodeScanner = false
    @State private var barcodeError: String?

    // Server-side, like the items list: with a paged catalogue a local filter only
    // searches what has been scrolled to, so building an invoice from a thousand
    // products would appear to be missing most of them.
    var filteredItems: [ItemResponse] { vm.items }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.sBackground.ignoresSafeArea()

                VStack(spacing: 0) {


                    // MARK: - Search Bar
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.body)
                            .foregroundStyle(Color.sMutedFG)

                        TextField("Search name or SKU", text: $searchText)
                            .onChange(of: searchText) { _, query in
                                vm.search(query)
                            }
                            .font(.body)
                            .foregroundStyle(Color.sForeground)
                            .tint(Color.sAccent)
                            .autocorrectionDisabled()

                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.body)
                                    .foregroundStyle(Color.sMutedFG)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.sCard)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.sInput, lineWidth: 0.5)
                    }
                    .clipShape(.rect(cornerRadius: 8))
                    .padding(.horizontal, AppSpacing.page)
                    .padding(.vertical, 14)

                    // MARK: - Add New Item Row
                    Button(action: { showAddItem = true }) {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(
                                        Color.sBorder,
                                        style: StrokeStyle(lineWidth: 1, dash: [4])
                                    )
                                    .frame(width: 40, height: 40)

                                Image(systemName: "plus")
                                    .font(.body)
                                    .foregroundStyle(Color.sMutedFG)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text("Add new item")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Color.sForeground)

                                Text("Create a new product or service")
                                    .font(.caption)
                                    .foregroundStyle(Color.sMutedFG)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Color.sMutedFG)
                        }
                        .padding(.horizontal, AppSpacing.page)
                        .padding(.vertical, 12)
                    }

                    Rectangle().fill(Color.sBorder).frame(height: 0.5).padding(.top, 4)

                    // MARK: - Items List
                    if vm.isLoading {
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(Color.sAccent)
                            Text("Loading items...")
                                .font(.subheadline)
                                .foregroundStyle(Color.sMutedFG)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if filteredItems.isEmpty {
                        VStack(spacing: 14) {
                            Image(systemName: "shippingbox")
                                .font(.scaled(36))
                                .foregroundStyle(Color.sMutedFG)

                            VStack(spacing: 4) {
                                Text(searchText.isEmpty ? "No items yet" : "No items found")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.sForeground)

                                Text(searchText.isEmpty ? "Add your first item to get started" : "Try a different search")
                                    .font(.footnote)
                                    .foregroundStyle(Color.sMutedFG)
                            }

                            if searchText.isEmpty {
                                Button(action: { showAddItem = true }) {
                                    Text("Add item")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Color.sAccentFG)
                                        .padding(.horizontal, AppSpacing.page)
                                        .padding(.vertical, 10)
                                        .background(Color.sPrimary)
                                        .clipShape(.rect(cornerRadius: 8))
                                }
                                .padding(.top, 4)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        HStack {
                            Text("Available items")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Color.sMutedFG)

                            Spacer()

                            Text("\(filteredItems.count)")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Color.sMutedFG)
                        }
                        .padding(.horizontal, AppSpacing.page)
                        .padding(.top, 14)
                        .padding(.bottom, 8)

                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVStack(spacing: 8) {
                                ForEach(filteredItems) { item in
                                    SelectItemRow(
                                        item: item,
                                        isSelected: selectedItems.contains(where: { $0.item.id == item.id }),
                                        onSelect: {
                                            if !selectedItems.contains(where: { $0.item.id == item.id }) {
                                                selectedItems.append(
                                                    InvoiceLineItem(
                                                        item: item,
                                                        qty: 1,
                                                        rate: item.price,
                                                        discount: 0,
                                                        taxRate: item.tax_rate ?? 18
                                                    )
                                                )
                                            }
                                            dismiss()
                                        }
                                    )
                                    .task {
                                        await vm.loadMoreIfNeeded(currentItem: item)
                                    }
                                }

                                if vm.isLoadingMore {
                                    ProgressView()
                                        .tint(Color.sAccent)
                                        .padding(.vertical, 12)
                                } else if vm.loadMoreFailed {
                                    // The picker shares the list's view model, which
                                    // stops paging after a failed page — so without a
                                    // way to retry here, the older items simply could
                                    // not be reached while adding a line.
                                    VStack(spacing: 6) {
                                        Text("Couldn't load more items.")
                                            .font(.subheadline)
                                            .foregroundStyle(Color.sMutedFG)
                                        Button("Try again") { Task { await vm.retryLoadMore() } }
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(Color.sAccent)
                                    }
                                    .padding(.vertical, 12)
                                }
                            }
                            .padding(.horizontal, AppSpacing.page)
                            .padding(.bottom, 20)
                        }
                    }
                }
            }
            .navigationTitle("Select items")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            showBarcodeScanner = true
                        } label: {
                            Image(systemName: "barcode.viewfinder")
                        }
                        Button(action: { showAddItem = true }) {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .task { await vm.loadItems() }
            .alert("Barcode scan", isPresented: Binding(
                get: { barcodeError != nil },
                set: { if !$0 { barcodeError = nil } }
            )) {
                Button("OK", role: .cancel) { barcodeError = nil }
            } message: {
                Text(barcodeError ?? "")
            }
            .sheet(isPresented: $showAddItem, onDismiss: {
                Task { await vm.loadItems() }
            }) {
                ItemFormView()
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $showBarcodeScanner) {
                ItemScannerView(onCancel: { showBarcodeScanner = false }) { code in
                    showBarcodeScanner = false
                    guard let companyID = SessionManager.shared.selectedCompanyId else { return }
                    Task {
                        do {
                            let item = try await ItemService().getItemByBarcode(companyID: companyID, barcode: code)
                            if let existing = selectedItems.firstIndex(where: { $0.item.id == item.id }) {
                                selectedItems[existing].qty += 1
                            } else {
                                selectedItems.append(InvoiceLineItem(
                                    item: item,
                                    qty: 1,
                                    rate: item.price,
                                    discount: 0,
                                    taxRate: item.tax_rate ?? 18
                                ))
                            }
                        } catch {
                            barcodeError = "No item found for barcode: \(code)"
                        }
                    }
                }
                .ignoresSafeArea()
            }
        }
    }
}

// MARK: - Select Item Row
struct SelectItemRow: View {
    let item: ItemResponse
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                Text(String(item.name.prefix(1)).uppercased())
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.sAccentFG)
                    .frame(width: 40, height: 40)
                    .background(Color.sAccent)
                    .clipShape(.rect(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.sForeground)
                        .lineLimit(1)

                    if let desc = item.description, !desc.isEmpty {
                        Text(desc)
                            .font(.caption)
                            .foregroundStyle(Color.sMutedFG)
                            .lineLimit(1)
                    }

                    if let unit = item.unit, !unit.isEmpty {
                        Text("Unit: \(unit)")
                            .font(.caption)
                            .foregroundStyle(Color.sMutedFG)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(Money.text(item.price)).moneyLine()
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.sForeground)

                    if let taxRate = item.tax_rate, taxRate > 0 {
                        Text("GST \(String(format: "%.0f", taxRate))%")
                            .font(.caption)
                            .foregroundStyle(Color.sMutedFG)
                    }

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.sAccent)
                    } else {
                        Image(systemName: "circle")
                            .font(.body)
                            .foregroundStyle(Color.sBorder)
                    }
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(Color.sCard)
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.sAccent.opacity(0.4) : Color.sBorder, lineWidth: 0.5)
            }
            .clipShape(.rect(cornerRadius: 10))
        }
    }
}

// MARK: - Preview
#Preview {
    SelectItemSheet(selectedItems: .constant([]))
}
