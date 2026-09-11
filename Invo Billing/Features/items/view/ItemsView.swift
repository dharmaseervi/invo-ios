import SwiftUI
import Vision

struct ItemsView: View {
    @StateObject var vm = ItemViewModel()
    @State private var searchText = ""
    @State private var selectedItemForEdit: ItemResponse?
    @State private var itemToPrint: ItemResponse?
    @State private var showLookupScanner = false
    @State private var lookupResult: ItemResponse?
    @State private var lookupNotFoundCode: String?
    @State private var isSelectMode = false
    @State private var selectedItemIDs: Set<Int> = []
    @State private var showBulkPrint = false

    var filteredItems: [ItemResponse] {
        if searchText.isEmpty { return vm.items }
        return vm.items.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    /// Matches a scanned code against an item — either this app's own printed label
    /// (encoded as "ITEM_ID:<id>", see PrintImageBuilder) or a real product SKU/barcode.
    static func matchScannedCode(_ code: String, in items: [ItemResponse]) -> ItemResponse? {
        if code.hasPrefix("ITEM_ID:"), let id = Int(code.dropFirst("ITEM_ID:".count)) {
            return items.first(where: { $0.id == id })
        }
        return items.first(where: { $0.sku == code })
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.sBackground.ignoresSafeArea()

                VStack(spacing: 0) {

                    // MARK: - Search Bar
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14))
                            .foregroundColor(.sMutedFG)

                        TextField("Search items", text: $searchText)
                            .font(.system(size: 14))
                            .foregroundColor(.sForeground)
                            .tint(.sAccent)
                            .autocorrectionDisabled()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.sCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.sInput, lineWidth: 0.5)
                    )
                    .cornerRadius(8)
                    .padding(.horizontal, 20)
                    .padding(.top, 14)

                    // MARK: - Content
                    Group {
                        if vm.isLoading {
                            VStack(spacing: 12) {
                                ProgressView()
                                    .tint(.sAccent)
                                Text("Loading items...")
                                    .font(.system(size: 13))
                                    .foregroundColor(.sMutedFG)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else if let error = vm.errorMessage {
                            VStack(spacing: 10) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 28))
                                    .foregroundColor(.sDestructive)

                                Text(error)
                                    .font(.system(size: 13))
                                    .foregroundColor(.sMutedFG)
                                    .multilineTextAlignment(.center)

                                // Retrying a rejected token can only fail again, so the
                                // button is offered only for failures a retry can fix.
                                if !vm.sessionExpired {
                                    Button(action: {
                                        Task { await vm.loadItems() }
                                    }) {
                                        Text("Try again")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.sAccent)
                                    }
                                    .padding(.top, 4)
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(24)
                        } else if filteredItems.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "box.2")
                                    .font(.system(size: 40))
                                    .foregroundColor(.sMutedFG)

                                VStack(spacing: 4) {
                                    Text("No items")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.sForeground)

                                    Text("Add your first item to get started")
                                        .font(.system(size: 13))
                                        .foregroundColor(.sMutedFG)
                                }

                                NavigationLink {
                                    ItemFormView()
                                } label: {
                                    Text("Add item")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.sAccentFG)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 10)
                                        .background(Color.sPrimary)
                                        .cornerRadius(8)
                                }
                                .padding(.top, 4)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            ScrollView(.vertical, showsIndicators: false) {
                                VStack(spacing: 10) {
                                    ForEach(filteredItems) { item in
                                        ItemListRowView(
                                            item: item,
                                            onTapRow: {
                                                if isSelectMode {
                                                    if selectedItemIDs.contains(item.id) {
                                                        selectedItemIDs.remove(item.id)
                                                    } else {
                                                        selectedItemIDs.insert(item.id)
                                                    }
                                                } else {
                                                    selectedItemForEdit = item
                                                }
                                            },
                                            onTapPrint: { itemToPrint = item },
                                            isSelectMode: isSelectMode,
                                            isSelected: selectedItemIDs.contains(item.id)
                                        )
                                    }
                                }
                                .padding(20)
                                .padding(.bottom, isSelectMode && !selectedItemIDs.isEmpty ? 70 : 0)
                            }
                        }
                    }

                    Spacer(minLength: 0)
                }

                if isSelectMode && !selectedItemIDs.isEmpty {
                    VStack {
                        Spacer()
                        bulkPrintBar
                    }
                }
            }
            .navigationTitle("Items")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if isSelectMode {
                        Button("Cancel") {
                            isSelectMode = false
                            selectedItemIDs.removeAll()
                        }
                    } else {
                        Button {
                            showLookupScanner = true
                        } label: {
                            Image(systemName: "barcode.viewfinder")
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if isSelectMode {
                        EmptyView()
                    } else {
                        HStack(spacing: 16) {
                            Button("Select") { isSelectMode = true }
                                .font(.system(size: 15))
                            NavigationLink {
                                ItemFormView()
                            } label: {
                                Image(systemName: "plus")
                            }
                        }
                    }
                }
            }
            .task {
                await vm.loadItems()
            }
            .onChange(of: SessionManager.shared.selectedCompanyId) { _ in
                Task { await vm.loadItems() }
            }
            .navigationDestination(item: $selectedItemForEdit) { item in
                ItemFormView(existingItem: item)
            }
            .navigationDestination(item: $itemToPrint) { item in
                PrintLabelScreen(item: item)
            }
            .navigationDestination(isPresented: $showBulkPrint) {
                BulkPrintLabelsScreen(items: vm.items.filter { selectedItemIDs.contains($0.id) })
            }
            .fullScreenCover(isPresented: $showLookupScanner) {
                ItemScannerView { code in
                    showLookupScanner = false
                    if let match = ItemsView.matchScannedCode(code, in: vm.items) {
                        lookupResult = match
                    } else {
                        lookupNotFoundCode = code
                    }
                }
                .ignoresSafeArea()
            }
            .sheet(item: $lookupResult) { item in
                ItemLookupResultSheet(item: item)
                    .presentationDetents([.medium])
            }
            .alert(
                "No match found",
                isPresented: Binding(
                    get: { lookupNotFoundCode != nil },
                    set: { if !$0 { lookupNotFoundCode = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("No item with SKU/barcode \"\(lookupNotFoundCode ?? "")\" was found.")
            }
        }
    }
}

extension ItemsView {
    fileprivate var bulkPrintBar: some View {
        HStack {
            Text("\(selectedItemIDs.count) selected")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.sMutedFG)

            Spacer()

            Button {
                showBulkPrint = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "printer.fill")
                    Text("Print labels")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.sAccentFG)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Color.sPrimary)
                .cornerRadius(10)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.sCard)
        .overlay(Rectangle().fill(Color.sBorder).frame(height: 0.5), alignment: .top)
    }
}

// MARK: - Item Lookup Result Sheet
struct ItemLookupResultSheet: View {
    let item: ItemResponse

    private var isLowStock: Bool {
        guard let alert = item.low_stock_alert, alert > 0 else { return false }
        return item.quantity <= alert
    }

    var body: some View {
        VStack(spacing: 20) {
            Text(item.name)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.sForeground)
                .padding(.top, 24)

            HStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text("₹\(String(format: "%.2f", item.price))")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.sForeground)
                    Text("Price")
                        .font(.system(size: 12))
                        .foregroundColor(.sMutedFG)
                }
                .frame(maxWidth: .infinity)

                Rectangle().fill(Color.sBorder).frame(width: 0.5, height: 40)

                VStack(spacing: 4) {
                    Text("\(item.quantity)")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(isLowStock ? .sDestructive : .sForeground)
                    Text(item.unit ?? "In stock")
                        .font(.system(size: 12))
                        .foregroundColor(.sMutedFG)
                }
                .frame(maxWidth: .infinity)
            }

            if isLowStock {
                Text(item.quantity <= 0 ? "Out of stock" : "Low stock")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.sDestructive)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.sDestructive.opacity(0.1))
                    .cornerRadius(6)
            }

            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Item List Row View
struct ItemListRowView: View {
    let item: ItemResponse
    let onTapRow: () -> Void
    let onTapPrint: () -> Void
    var isSelectMode: Bool = false
    var isSelected: Bool = false

    private var isLowStock: Bool {
        guard let alert = item.low_stock_alert, alert > 0 else { return false }
        return item.quantity <= alert
    }

    var body: some View {
        HStack(spacing: 12) {
            if isSelectMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .sAccent : .sBorder)
            }

            Button(action: onTapRow) {
                HStack(spacing: 12) {
                    Text(String(item.name.prefix(1)).uppercased())
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.sAccentFG)
                        .frame(width: 44, height: 44)
                        .background(Color.sAccent)
                        .cornerRadius(10)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(item.name)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.sForeground)

                            if isLowStock {
                                Text(item.quantity <= 0 ? "Out of stock" : "Low stock")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(.sDestructive)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.sDestructive.opacity(0.1))
                                    .cornerRadius(4)
                            }
                        }

                        HStack(spacing: 8) {
                            Text("₹\(String(format: "%.2f", item.price))")
                                .font(.system(size: 12))
                                .foregroundColor(.sForeground)

                            Text("•")
                                .foregroundColor(.sMutedFG)
                            Text("\(item.quantity) \(item.unit ?? "in stock")")
                                .font(.system(size: 11))
                                .foregroundColor(isLowStock ? .sDestructive : .sMutedFG)

                            if let desc = item.description, !desc.isEmpty {
                                Text("•")
                                    .foregroundColor(.sMutedFG)
                                Text(desc)
                                    .font(.system(size: 11))
                                    .foregroundColor(.sMutedFG)
                                    .lineLimit(1)
                            }
                        }
                    }

                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if !isSelectMode {
                Button(action: onTapPrint) {
                    Image(systemName: "qrcode")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.sMutedFG)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(Color.sCard)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.sBorder, lineWidth: 0.5)
        )
        .cornerRadius(12)
    }
}
