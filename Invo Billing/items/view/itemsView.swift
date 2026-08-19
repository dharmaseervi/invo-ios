import SwiftUI
import Vision

struct itemsView: View {
    @StateObject var vm = ItemViewModel()
    @State private var searchText = ""
    @State private var selectedItem: ItemResponse?
    @State private var showQRModal = false
    @Environment(\.displayScale) private var displayScale
    @State private var selectedLabelSize: LabelSize = .medium
    @State private var showLabelSizeSheet = false
    @State private var itemToPrint: ItemResponse?

    var filteredItems: [ItemResponse] {
        if searchText.isEmpty { return vm.items }
        return vm.items.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()

                VStack(spacing: 0) {

                    // MARK: - Header
                    VStack(alignment: .leading, spacing: 16) {
                        Text("ITEMS")
                            .font(
                                .system(
                                    size: 28,
                                    weight: .thin,
                                    design: .default
                                )
                            )
                            .tracking(0.5)

                        Divider()
                            .frame(height: 1)
                            .background(Color.black)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 24)

                    // MARK: - Search Bar
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14, weight: .light))
                            .foregroundColor(.black.opacity(0.4))

                        TextField("Search items", text: $searchText)
                            .font(
                                .system(
                                    size: 14,
                                    weight: .light,
                                    design: .default
                                )
                            )
                            .foregroundColor(.black)
                            .autocorrectionDisabled()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.02))
                    .overlay(
                        RoundedRectangle(cornerRadius: 0)
                            .stroke(Color.black.opacity(0.1), lineWidth: 1)
                    )
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)

                    // MARK: - Content
                    Group {
                        if vm.isLoading {
                            VStack(spacing: 16) {
                                ProgressView()
                                    .tint(.black)
                                Text("Loading items...")
                                    .font(
                                        .system(
                                            size: 13,
                                            weight: .light,
                                            design: .default
                                        )
                                    )
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else if let error = vm.errorMessage {
                            VStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 32, weight: .thin))
                                    .foregroundColor(.red)

                                Text("Error")
                                    .font(
                                        .system(
                                            size: 14,
                                            weight: .semibold,
                                            design: .default
                                        )
                                    )

                                Text(error)
                                    .font(
                                        .system(
                                            size: 12,
                                            weight: .light,
                                            design: .default
                                        )
                                    )
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)

                                Button(action: {
                                    Task {
                                        await vm.loadItems()
                                    }
                                }) {
                                    Text("TRY AGAIN")
                                        .font(
                                            .system(
                                                size: 12,
                                                weight: .semibold,
                                                design: .default
                                            )
                                        )
                                        .tracking(0.5)
                                        .padding(.horizontal, 24)
                                        .padding(.vertical, 10)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 0)
                                                .stroke(
                                                    Color.black,
                                                    lineWidth: 1
                                                )
                                        )
                                        .foregroundColor(.black)
                                }
                                .padding(.top, 8)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(24)
                        } else if filteredItems.isEmpty {
                            VStack(spacing: 24) {
                                Image(systemName: "box.2")
                                    .font(.system(size: 48, weight: .thin))
                                    .foregroundColor(.black.opacity(0.2))

                                VStack(spacing: 8) {
                                    Text("No Items")
                                        .font(
                                            .system(
                                                size: 16,
                                                weight: .semibold,
                                                design: .default
                                            )
                                        )
                                        .tracking(0.3)

                                    Text("Add your first item to get started")
                                        .font(
                                            .system(
                                                size: 12,
                                                weight: .light,
                                                design: .default
                                            )
                                        )
                                        .foregroundColor(.gray)
                                }

                                NavigationLink {
                                    ItemFormView()
                                } label: {
                                    Text("ADD ITEM")
                                        .font(
                                            .system(
                                                size: 12,
                                                weight: .semibold,
                                                design: .default
                                            )
                                        )
                                        .tracking(0.5)
                                        .padding(.vertical, 12)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 20)
                                        .background(Color.black)
                                        
                                }
                                .padding(.top, 8)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            ScrollView(.vertical, showsIndicators: false) {
                                VStack(spacing: 0) {
                                    ForEach(filteredItems) { item in
                                        ItemListRowView(item: item) {
                                            selectedItem = item
                                            showQRModal = true
                                        }

                                        if item.id != filteredItems.last?.id {
                                            Divider()
                                                .frame(height: 1)
                                                .background(
                                                    Color.black.opacity(0.08)
                                                )
                                                .padding(.horizontal, 24)
                                        }
                                    }
                                }

                            }
                        }
                    }

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(false)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        ItemFormView()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.black)
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
    let onQRTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 16) {
                // Avatar
                Text(String(item.name.prefix(1)).uppercased())
                    .font(
                        .system(size: 14, weight: .semibold, design: .default)
                    )
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black)
                    .cornerRadius(4)

                // Item Info
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.name)
                        .font(
                            .system(
                                size: 14,
                                weight: .semibold,
                                design: .default
                            )
                        )
                        .foregroundColor(.black)

                    HStack(spacing: 12) {
                        Text("₹\(String(format: "%.2f", item.price))")
                            .font(
                                .system(
                                    size: 12,
                                    weight: .light,
                                    design: .default
                                )
                            )
                            .foregroundColor(.black)

                        if let desc = item.description, !desc.isEmpty {
                            Text("•")
                                .foregroundColor(.gray.opacity(0.5))
                            Text(desc)
                                .font(
                                    .system(
                                        size: 11,
                                        weight: .light,
                                        design: .default
                                    )
                                )
                                .foregroundColor(.gray)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer()

                // Menu
                Menu {
                    NavigationLink {
                        PrintLabelScreen(item: item)
                    } label: {
                        Label("Print QR Label", systemImage: "printer")
                    }

                    Button(action: {}) {
                        Label("AirPrint Barcode", systemImage: "printer")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.black.opacity(0.4))
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .background(Color.white)
    }
}
