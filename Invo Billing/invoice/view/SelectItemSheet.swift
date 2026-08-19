import SwiftUI

struct SelectItemSheet: View {
    @Binding var selectedItems: [InvoiceLineItem]
    @Environment(\.dismiss) var dismiss
    
    @StateObject var vm = ItemViewModel()
    @State private var searchText = ""
    @State private var showAddItem = false  // ✅ New state for add item sheet
    
    var filteredItems: [ItemResponse] {
        if searchText.isEmpty { return vm.items }
        return vm.items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    
                    // MARK: - Header
                    HStack {
                        Button(action: { dismiss() }) {
                            HStack(spacing: 8) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Back")
                                    .font(.system(size: 14, weight: .light, design: .default))
                            }
                            .foregroundColor(.black)
                        }
                        
                        Spacer()
                        
                        Text("SELECT ITEMS")
                            .font(.system(size: 12, weight: .semibold, design: .default))
                            .tracking(0.5)
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        // ✅ Changed to Add Item Button
                        Button(action: { showAddItem = true }) {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.black)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    
                    Divider()
                        .frame(height: 1)
                        .background(Color.black.opacity(0.08))
                    
                    // MARK: - Search Bar
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14, weight: .light))
                            .foregroundColor(.black.opacity(0.4))
                        
                        TextField("Search items", text: $searchText)
                            .font(.system(size: 14, weight: .light, design: .default))
                            .foregroundColor(.black)
                            .autocorrectionDisabled()
                        
                        // ✅ Clear button
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.black.opacity(0.3))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.02))
                    .overlay(
                        RoundedRectangle(cornerRadius: 0)
                            .stroke(Color.black.opacity(0.1), lineWidth: 1)
                    )
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    
                    // MARK: - Add New Item Row ✅
                    Button(action: { showAddItem = true }) {
                        HStack(spacing: 14) {
                            // Dashed square with plus
                            ZStack {
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(
                                        Color.black.opacity(0.3),
                                        style: StrokeStyle(lineWidth: 1, dash: [4])
                                    )
                                    .frame(width: 40, height: 40)
                                
                                Image(systemName: "plus")
                                    .font(.system(size: 16, weight: .light))
                                    .foregroundColor(.black.opacity(0.5))
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Add New Item")
                                    .font(.system(size: 13, weight: .semibold, design: .default))
                                    .foregroundColor(.black)
                                
                                Text("Create a new product or service")
                                    .font(.system(size: 11, weight: .light, design: .default))
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.black.opacity(0.3))
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.black.opacity(0.02))
                    }
                    
                    Divider()
                        .frame(height: 1)
                        .background(Color.black.opacity(0.08))
                        .padding(.top, 8)
                    
                    // MARK: - Items List
                    if vm.isLoading {
                        VStack(spacing: 16) {
                            ProgressView()
                                .tint(.black)
                            Text("Loading items...")
                                .font(.system(size: 13, weight: .light, design: .default))
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if filteredItems.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "shippingbox")
                                .font(.system(size: 40, weight: .thin))
                                .foregroundColor(.black.opacity(0.2))
                            
                            VStack(spacing: 6) {
                                Text(searchText.isEmpty ? "No Items Yet" : "No Items Found")
                                    .font(.system(size: 14, weight: .semibold, design: .default))
                                    .tracking(0.3)
                                
                                Text(searchText.isEmpty ? "Add your first item to get started" : "Try a different search")
                                    .font(.system(size: 12, weight: .light, design: .default))
                                    .foregroundColor(.gray)
                            }
                            
                            // ✅ Add item button in empty state
                            if searchText.isEmpty {
                                Button(action: { showAddItem = true }) {
                                    Text("ADD ITEM")
                                        .font(.system(size: 12, weight: .semibold, design: .default))
                                        .tracking(0.5)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 24)
                                        .padding(.vertical, 12)
                                        .background(Color.black)
                                }
                                .padding(.top, 8)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        // ✅ Section header
                        HStack {
                            Text("AVAILABLE ITEMS")
                                .font(.system(size: 10, weight: .semibold, design: .default))
                                .tracking(0.8)
                                .foregroundColor(.gray)
                            
                            Spacer()
                            
                            Text("\(filteredItems.count)")
                                .font(.system(size: 10, weight: .semibold, design: .default))
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                        .padding(.bottom, 8)
                        
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVStack(spacing: 0) {
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
                                    
                                    if item.id != filteredItems.last?.id {
                                        Divider()
                                            .frame(height: 1)
                                            .background(Color.black.opacity(0.08))
                                            .padding(.horizontal, 24)
                                    }
                                }
                            }
                            .padding(.bottom, 24)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .task { await vm.loadItems() }
            
            // ✅ Add Item Sheet
            .sheet(isPresented: $showAddItem, onDismiss: {
                // Refresh items list after adding new item
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
                // Avatar
                Text(String(item.name.prefix(1)).uppercased())
                    .font(.system(size: 12, weight: .semibold, design: .default))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(isSelected ? Color.black : Color.black.opacity(0.85))
                    .cornerRadius(4)
                
                // Item Info
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.name)
                        .font(.system(size: 13, weight: .semibold, design: .default))
                        .foregroundColor(.black)
                        .lineLimit(1)
                    
                    if let desc = item.description, !desc.isEmpty {
                        Text(desc)
                            .font(.system(size: 11, weight: .light, design: .default))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                    
                    // ✅ Show unit if available
                    if let unit = item.unit, !unit.isEmpty {
                        Text("Unit: \(unit)")
                            .font(.system(size: 10, weight: .light, design: .default))
                            .foregroundColor(.gray.opacity(0.6))
                            .tracking(0.2)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 6) {
                    Text("₹\(String(format: "%.2f", item.price))")
                        .font(.system(size: 13, weight: .semibold, design: .default))
                        .foregroundColor(.black)
                    
                    // ✅ Show tax rate if available
                    if let taxRate = item.tax_rate, taxRate > 0 {
                        Text("GST \(String(format: "%.0f", taxRate))%")
                            .font(.system(size: 10, weight: .light, design: .default))
                            .foregroundColor(.gray)
                    }
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.black)
                    } else {
                        Image(systemName: "circle")
                            .font(.system(size: 14, weight: .light))
                            .foregroundColor(.black.opacity(0.3))
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(isSelected ? Color.black.opacity(0.02) : Color.white)
        }
    }
}

// MARK: - Preview
#Preview {
    SelectItemSheet(selectedItems: .constant([]))
}
