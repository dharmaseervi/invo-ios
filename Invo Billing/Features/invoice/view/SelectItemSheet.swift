import SwiftUI

struct SelectItemSheet: View {
    @Binding var selectedItems: [InvoiceLineItem]
    @Environment(\.dismiss) var dismiss

    @StateObject var vm = ItemViewModel()
    @State private var searchText = ""
    @State private var showAddItem = false

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
                            .font(.scaled(14))
                            .foregroundColor(.sMutedFG)

                        TextField("Search name or SKU", text: $searchText)
                            .onChange(of: searchText) { _, query in
                                vm.search(query)
                            }
                            .font(.scaled(14))
                            .foregroundColor(.sForeground)
                            .tint(.sAccent)
                            .autocorrectionDisabled()

                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.scaled(14))
                                    .foregroundColor(.sMutedFG)
                            }
                        }
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
                                    .font(.scaled(16))
                                    .foregroundColor(.sMutedFG)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text("Add new item")
                                    .font(.scaled(13, weight: .medium))
                                    .foregroundColor(.sForeground)

                                Text("Create a new product or service")
                                    .font(.scaled(11))
                                    .foregroundColor(.sMutedFG)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.scaled(12, weight: .semibold))
                                .foregroundColor(.sMutedFG)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    }

                    Rectangle().fill(Color.sBorder).frame(height: 0.5).padding(.top, 4)

                    // MARK: - Items List
                    if vm.isLoading {
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(.sAccent)
                            Text("Loading items...")
                                .font(.scaled(13))
                                .foregroundColor(.sMutedFG)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if filteredItems.isEmpty {
                        VStack(spacing: 14) {
                            Image(systemName: "shippingbox")
                                .font(.scaled(36))
                                .foregroundColor(.sMutedFG)

                            VStack(spacing: 4) {
                                Text(searchText.isEmpty ? "No items yet" : "No items found")
                                    .font(.scaled(14, weight: .semibold))
                                    .foregroundColor(.sForeground)

                                Text(searchText.isEmpty ? "Add your first item to get started" : "Try a different search")
                                    .font(.scaled(12))
                                    .foregroundColor(.sMutedFG)
                            }

                            if searchText.isEmpty {
                                Button(action: { showAddItem = true }) {
                                    Text("Add item")
                                        .font(.scaled(13, weight: .semibold))
                                        .foregroundColor(.sAccentFG)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 10)
                                        .background(Color.sPrimary)
                                        .cornerRadius(8)
                                }
                                .padding(.top, 4)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        HStack {
                            Text("Available items")
                                .font(.scaled(11, weight: .medium))
                                .foregroundColor(.sMutedFG)

                            Spacer()

                            Text("\(filteredItems.count)")
                                .font(.scaled(11, weight: .medium))
                                .foregroundColor(.sMutedFG)
                        }
                        .padding(.horizontal, 20)
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
                                        .tint(.sAccent)
                                        .padding(.vertical, 12)
                                }
                            }
                            .padding(.horizontal, 20)
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
                    Button(action: { showAddItem = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .task { await vm.loadItems() }

            .sheet(isPresented: $showAddItem, onDismiss: {
                Task { await vm.loadItems() }
            }) {
                ItemFormView()
                    .presentationDetents([.large])
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
                    .font(.scaled(12, weight: .semibold))
                    .foregroundColor(.sAccentFG)
                    .frame(width: 40, height: 40)
                    .background(Color.sAccent)
                    .cornerRadius(10)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.scaled(13, weight: .medium))
                        .foregroundColor(.sForeground)
                        .lineLimit(1)

                    if let desc = item.description, !desc.isEmpty {
                        Text(desc)
                            .font(.scaled(11))
                            .foregroundColor(.sMutedFG)
                            .lineLimit(1)
                    }

                    if let unit = item.unit, !unit.isEmpty {
                        Text("Unit: \(unit)")
                            .font(.scaled(10))
                            .foregroundColor(.sMutedFG)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(Money.text(item.price)).moneyLine()
                        .font(.scaled(13, weight: .semibold))
                        .foregroundColor(.sForeground)

                    if let taxRate = item.tax_rate, taxRate > 0 {
                        Text("GST \(String(format: "%.0f", taxRate))%")
                            .font(.scaled(10))
                            .foregroundColor(.sMutedFG)
                    }

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.scaled(14, weight: .semibold))
                            .foregroundColor(.sAccent)
                    } else {
                        Image(systemName: "circle")
                            .font(.scaled(14))
                            .foregroundColor(.sBorder)
                    }
                }
            }
            .padding(14)
            .background(Color.sCard)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.sAccent.opacity(0.4) : Color.sBorder, lineWidth: 0.5)
            )
            .cornerRadius(10)
        }
    }
}

// MARK: - Preview
#Preview {
    SelectItemSheet(selectedItems: .constant([]))
}
