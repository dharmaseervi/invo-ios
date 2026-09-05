import SwiftUI
import Vision

struct ItemsView: View {
    @StateObject var vm = ItemViewModel()
    @State private var searchText = ""

    var filteredItems: [ItemResponse] {
        if searchText.isEmpty { return vm.items }
        return vm.items.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
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

                                Button(action: {
                                    Task { await vm.loadItems() }
                                }) {
                                    Text("Try again")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.sAccent)
                                }
                                .padding(.top, 4)
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
                                        ItemListRowView(item: item)
                                    }
                                }
                                .padding(20)
                            }
                        }
                    }

                    Spacer(minLength: 0)
                }
            }
            .navigationTitle("Items")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        ItemFormView()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .task {
                await vm.loadItems()
            }
            .onChange(of: SessionManager.shared.selectedCompanyId) { _ in
                Task { await vm.loadItems() }
            }
        }
    }
}

// MARK: - Item List Row View
struct ItemListRowView: View {
    let item: ItemResponse

    private var isLowStock: Bool {
        guard let alert = item.low_stock_alert, alert > 0 else { return false }
        return item.quantity <= alert
    }

    var body: some View {
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

            NavigationLink {
                PrintLabelScreen(item: item)
            } label: {
                Image(systemName: "qrcode")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.sMutedFG)
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
