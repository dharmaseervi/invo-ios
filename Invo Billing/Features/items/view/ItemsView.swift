import SwiftUI
import Vision

struct ItemsView: View {
    #if DEBUG
    @State private var debugItemForm = false
    #endif
    @StateObject var vm = ItemViewModel()
    @State private var searchText = ""
    @State private var selectedItemForEdit: ItemResponse?
    @State private var itemToPrint: ItemResponse?
    @State private var showLookupScanner = false
    @State private var lookupResult: ItemResponse?
    @State private var lookupNotFoundCode: String?
    @State private var isSelectMode = false
    @State private var showImport = false
    @State private var selectedItemIDs: Set<Int> = []
    @State private var showBulkPrint = false

    // Filtering happens on the server now. Matching locally only works while the whole
    // catalogue is in memory, which is exactly what paging stops doing — a local search
    // would silently miss anything the user had not yet scrolled to.
    var filteredItems: [ItemResponse] { vm.items }

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
            contentArea
                .navigationTitle("Items")
                #if DEBUG
                .navigationDestination(isPresented: $debugItemForm) { ItemFormView() }
                .onAppear {
                    if UserDefaults.standard.string(forKey: "startScreen") == "itemform" { debugItemForm = true }
                }
                #endif
                .navigationBarTitleDisplayMode(.large)
                .searchable(text: $searchText, prompt: "Search name or SKU")
                .onChange(of: searchText) { _, query in
                    vm.search(query)
                }
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
                                    .font(.subheadline)
                                Menu {
                                    NavigationLink {
                                        ItemFormView()
                                    } label: {
                                        Label("New product", systemImage: "plus")
                                    }
                                    Button {
                                        showImport = true
                                    } label: {
                                        Label("Import from CSV", systemImage: "tablecells")
                                    }
                                } label: {
                                    Image(systemName: "plus")
                                }
                            }
                        }
                    }
                }
                .task { await vm.loadItems() }
                .onChange(of: SessionManager.shared.selectedCompanyId) { _ in
                    Task { await vm.loadItems() }
                }
                .navigationDestination(item: $selectedItemForEdit) { item in
                    ItemFormView(existingItem: item)
                }
                .navigationDestination(item: $itemToPrint) { item in
                    PrintLabelScreen(item: item)
                }
                .navigationDestination(isPresented: $showImport) {
                    ImportItemsView { imported in
                        if imported { Task { await vm.loadItems() } }
                    }
                }
                .navigationDestination(isPresented: $showBulkPrint) {
                    BulkPrintLabelsScreen(items: vm.items.filter { selectedItemIDs.contains($0.id) })
                }
                .fullScreenCover(isPresented: $showLookupScanner) {
                    ItemScannerView(onCancel: { showLookupScanner = false }) { code in
                        showLookupScanner = false
                        Task {
                            if let match = await vm.findByCode(code) {
                                lookupResult = match
                            } else {
                                lookupNotFoundCode = code
                            }
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

    @ViewBuilder
    private var contentArea: some View {
        if vm.isLoading && vm.items.isEmpty {
            VStack(spacing: 12) {
                ProgressView().tint(.sAccent)
                Text("Loading items...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = vm.errorMessage {
            VStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title)
                    .foregroundStyle(Color.sDestructive)
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                if !vm.sessionExpired {
                    Button(action: {
                        Task { await vm.loadItems() }
                    }) {
                        Text("Try again")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.sAccent)
                    }
                    .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(24)
        } else {
            List {
                if filteredItems.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "box.2")
                            .font(.scaled(40))
                            .foregroundStyle(.secondary)
                        VStack(spacing: 4) {
                            Text("No items")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text("Add your first item to get started")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        NavigationLink {
                            ItemFormView()
                        } label: {
                            Text("Add item")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.sAccentFG)
                                .padding(.horizontal, AppSpacing.page)
                                .padding(.vertical, 10)
                                .background(Color.sPrimary)
                                .cornerRadius(8)
                        }
                        .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                } else {
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
                        .standardListRow()
                        .listRowSeparator(.hidden, edges: item.id == filteredItems.first?.id ? .top : [])
                        .task { await vm.loadMoreIfNeeded(currentItem: item) }
                    }

                    if vm.isLoadingMore {
                        HStack { Spacer(); ProgressView().tint(.sAccent); Spacer() }
                            .padding(.vertical, 12)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    } else if vm.loadMoreFailed {
                        VStack(spacing: 6) {
                            Text("Couldn't load more items.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Button("Try again") { Task { await vm.retryLoadMore() } }
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color.sAccent)
                        }
                        .padding(.vertical, 12)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    } else if !vm.hasMore && filteredItems.count > 20 {
                        Text("All \(filteredItems.count) items loaded")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 12)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                }
            }
            .listStyle(.plain)
            .contentMargins(.bottom, isSelectMode && !selectedItemIDs.isEmpty ? 80 : 16, for: .scrollContent)
            .overlay(alignment: .top) {
                if vm.isLoading && !vm.items.isEmpty {
                    ProgressView()
                        .tint(.sAccent)
                        .padding(8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .transition(.opacity)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if isSelectMode && !selectedItemIDs.isEmpty {
                    bulkPrintBar
                }
            }
        }
    }
}

extension ItemsView {
    fileprivate var bulkPrintBar: some View {
        HStack {
            Text("\(selectedItemIDs.count) selected")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                showBulkPrint = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "printer.fill")
                    Text("Print labels")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.sAccentFG)
                .padding(.horizontal, AppSpacing.page)
                .padding(.vertical, 10)
                .background(Color.sPrimary)
                .cornerRadius(10)
            }
        }
        .padding(.horizontal, AppSpacing.page)
        .padding(.vertical, 14)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .overlay(Rectangle().fill(Color(UIColor.separator)).frame(height: 0.5), alignment: .top)
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
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(.top, 24)

            HStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text(Money.text(item.price)).moneyLine()
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.primary)
                    Text("Price")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                Rectangle().fill(Color(UIColor.separator)).frame(width: 0.5, height: 40)

                VStack(spacing: 4) {
                    Text("\(item.quantity)")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(isLowStock ? Color.sDestructive : .primary)
                    Text(item.unit ?? "In stock")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }

            if isLowStock {
                Text(item.quantity <= 0 ? "Out of stock" : "Low stock")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.sDestructive)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.sDestructive.opacity(0.1))
                    .cornerRadius(6)
            }

            Spacer()
        }
        .padding(.horizontal, AppSpacing.page)
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
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.sAccent : Color(UIColor.tertiaryLabel))
            }

            Button(action: onTapRow) {
                HStack(spacing: 12) {
                    Text(String(item.name.prefix(1)).uppercased())
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.sAccentFG)
                        .frame(width: 40, height: 40)
                        .background(Color.sAccent, in: RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(item.name)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)

                            if isLowStock {
                                Text(item.quantity <= 0 ? "Out of stock" : "Low stock")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.sDestructive)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.sDestructive.opacity(0.1))
                                    .cornerRadius(4)
                            }
                        }
                        .alignmentGuide(.listRowSeparatorLeading) { d in d[.leading] }

                        HStack(spacing: 8) {
                            Text(Money.text(item.price)).moneyLine()
                                .font(.footnote)
                                .foregroundStyle(.primary)

                            Text("•")
                                .foregroundStyle(.tertiary)
                            Text("\(item.quantity) \(item.unit ?? "in stock")")
                                .font(.caption)
                                .foregroundStyle(isLowStock ? Color.sDestructive : .secondary)

                            if let desc = item.description, !desc.isEmpty {
                                Text("•")
                                    .foregroundStyle(.tertiary)
                                Text(desc)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
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
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
