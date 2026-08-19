import SwiftUI

struct ItemsSection: View {
    @Binding var invoiceItems: [InvoiceLineItem]
    @Binding var editingItem: InvoiceLineItem?
    @Binding var showItemPicker: Bool
    @State private var showEditSheet = false
    @Binding var showScanner: Bool
    @State private var itemToDelete: InvoiceLineItem?
    @State private var showDeleteConfirm = false
    
    var totalItems: Int {
        invoiceItems.count
    }
    
    var totalAmount: Double {
        invoiceItems.reduce(0) { $0 + $1.total }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("ITEMS")
                .font(.system(size: 11, weight: .semibold, design: .default))
                .tracking(1)
                .foregroundColor(.black)
                .padding(.horizontal, 24)
                .padding(.top, 28)
                .padding(.bottom, 16)
            
            if invoiceItems.isEmpty {
                // Empty State
                VStack(spacing: 16) {
                    Image(systemName: "box.2")
                        .font(.system(size: 40, weight: .thin))
                        .foregroundColor(.black.opacity(0.2))
                    
                    VStack(spacing: 6) {
                        Text("No Items Added")
                            .font(.system(size: 14, weight: .semibold, design: .default))
                            .tracking(0.3)
                        
                        Text("Add items to create your invoice")
                            .font(.system(size: 12, weight: .light, design: .default))
                            .foregroundColor(.gray)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(Color.black.opacity(0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 0)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            } else {
                // Items Summary
                VStack(spacing: 8) {
                    HStack {
                        Text("Total Items")
                            .font(.system(size: 11, weight: .regular, design: .default))
                            .foregroundColor(.gray)
                            .tracking(0.3)
                        Spacer()
                        Text("\(totalItems)")
                            .font(.system(size: 13, weight: .light, design: .default))
                            .foregroundColor(.black)
                    }
                    
                    Divider()
                        .frame(height: 1)
                        .background(Color.black.opacity(0.08))
                    
                    HStack {
                        Text("Total Amount")
                            .font(.system(size: 11, weight: .regular, design: .default))
                            .foregroundColor(.gray)
                            .tracking(0.3)
                        Spacer()
                        Text("₹\(String(format: "%.2f", totalAmount))")
                            .font(.system(size: 13, weight: .light, design: .default))
                            .foregroundColor(.black)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 0)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
                
                // Items List
                VStack(spacing: 0) {
                    ForEach(invoiceItems) { item in
                        ItemRowZara(
                            item: item,
                            onEdit: {
                                editingItem = item
                                showEditSheet = true
                            },
                            onDelete: {
                                itemToDelete = item
                                showDeleteConfirm = true
                            }
                        )
                        
                        if item.id != invoiceItems.last?.id {
                            Divider()
                                .frame(height: 1)
                                .background(Color.black.opacity(0.08))
                                .padding(.horizontal, 24)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
            
            // Add Item Buttons
            VStack(spacing: 8) {
                Button(action: { showItemPicker = true }) {
                    HStack {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 12, weight: .semibold))
                        Text("ADD ITEM")
                            .font(.system(size: 12, weight: .semibold, design: .default))
                            .tracking(0.5)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundColor(.black)
                    .overlay(
                        RoundedRectangle(cornerRadius: 0)
                            .stroke(Color.black, lineWidth: 1)
                    )
                }
                
                Button(action: { showScanner = true }) {
                    HStack {
                        Image(systemName: "barcode.viewfinder")
                            .font(.system(size: 12, weight: .semibold))
                        Text("SCAN ITEM")
                            .font(.system(size: 12, weight: .semibold, design: .default))
                            .tracking(0.5)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundColor(.black)
                    .overlay(
                        RoundedRectangle(cornerRadius: 0)
                            .stroke(Color.black, lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
        .sheet(isPresented: $showEditSheet) {
            if editingItem != nil {
                EditItemSheetZara(
                    item: $editingItem,
                    invoiceItems: $invoiceItems,
                    isPresented: $showEditSheet
                )
            }
        }
        .alert(
            "Delete Item",
            isPresented: $showDeleteConfirm,
            actions: {
                Button("Delete", role: .destructive) {
                    if let item = itemToDelete {
                        invoiceItems.removeAll { $0.id == item.id }
                    }
                    itemToDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    itemToDelete = nil
                }
            },
            message: {
                Text("Are you sure you want to remove this item from the invoice?")
            }
        )
    }
}

// MARK: - Item Row Component
struct ItemRowZara: View {
    let item: InvoiceLineItem
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                // Item Avatar
                Text(String(item.item.name.prefix(1)).uppercased())
                    .font(.system(size: 12, weight: .semibold, design: .default))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.black)
                    .cornerRadius(4)
                
                // Item Info
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.item.name)
                        .font(.system(size: 13, weight: .semibold, design: .default))
                        .foregroundColor(.black)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        Text("Qty: \(item.qty)")
                            .font(.system(size: 11, weight: .light, design: .default))
                            .foregroundColor(.gray)
                        
                        Text("•")
                            .foregroundColor(.gray.opacity(0.5))
                        
                        Text("₹\(String(format: "%.2f", item.rate))")
                            .font(.system(size: 11, weight: .light, design: .default))
                            .foregroundColor(.gray)
                        
                        if item.discount > 0 {
                            Text("•")
                                .foregroundColor(.gray.opacity(0.5))
                            
                            Text("Disc: ₹\(String(format: "%.2f", item.discount))")
                                .font(.system(size: 11, weight: .light, design: .default))
                                .foregroundColor(.black.opacity(0.6))
                        }
                    }
                }
                
                Spacer()
                
                // Amount and Actions
                VStack(alignment: .trailing, spacing: 8) {
                    Text("₹\(String(format: "%.2f", item.total))")
                        .font(.system(size: 13, weight: .semibold, design: .default))
                        .foregroundColor(.black)
                    
                    HStack(spacing: 12) {
                        Button(action: onEdit) {
                            Image(systemName: "pencil")
                                .font(.system(size: 10, weight: .light))
                                .foregroundColor(.black.opacity(0.4))
                        }
                        
                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .font(.system(size: 10, weight: .light))
                                .foregroundColor(.red.opacity(0.6))
                        }
                    }
                }
            }
            .padding(.horizontal, 0)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - Edit Item Sheet (Zara Style)
struct EditItemSheetZara: View {
    @Binding var item: InvoiceLineItem?
    @Binding var invoiceItems: [InvoiceLineItem]
    @Binding var isPresented: Bool
    @Environment(\.dismiss) var dismiss
    
    @State private var qty: Int = 1
    @State private var rate: Double = 0
    @State private var discount: Double = 0
    @State private var taxRate: Double = 18
    
    var subtotal: Double {
        (rate * Double(qty)) - discount
    }
    
    var taxAmount: Double {
        subtotal * (taxRate / 100)
    }
    
    var total: Double {
        subtotal + taxAmount
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()
                
                if let currentItem = item {
                    VStack(spacing: 0) {
                        
                        // Header
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
                            
                            Text("EDIT ITEM")
                                .font(.system(size: 12, weight: .semibold, design: .default))
                                .tracking(0.5)
                                .foregroundColor(.gray)
                            
                            Spacer()
                            
                            Image(systemName: "pencil.circle")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.black)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        
                        Divider()
                            .frame(height: 1)
                            .background(Color.black.opacity(0.08))
                        
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 0) {
                                
                                // Item Display
                                VStack(alignment: .leading, spacing: 0) {
                                    Text("ITEM")
                                        .font(.system(size: 11, weight: .semibold, design: .default))
                                        .tracking(1)
                                        .foregroundColor(.black)
                                        .padding(.horizontal, 24)
                                        .padding(.top, 28)
                                        .padding(.bottom, 16)
                                    
                                    HStack(spacing: 12) {
                                        Text(String(currentItem.item.name.prefix(1)).uppercased())
                                            .font(.system(size: 12, weight: .semibold, design: .default))
                                            .foregroundColor(.white)
                                            .frame(width: 44, height: 44)
                                            .background(Color.black)
                                            .cornerRadius(4)
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(currentItem.item.name)
                                                .font(.system(size: 13, weight: .semibold, design: .default))
                                                .foregroundColor(.black)
                                            
                                            if let desc = currentItem.item.description {
                                                Text(desc)
                                                    .font(.system(size: 11, weight: .light, design: .default))
                                                    .foregroundColor(.gray)
                                                    .lineLimit(1)
                                            }
                                        }
                                        
                                        Spacer()
                                    }
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(Color.black.opacity(0.02))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 0)
                                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                                    )
                                    .padding(.horizontal, 24)
                                    .padding(.bottom, 28)
                                }
                                
                                // Quantity Section
                                VStack(alignment: .leading, spacing: 0) {
                                    Text("QUANTITY")
                                        .font(.system(size: 11, weight: .semibold, design: .default))
                                        .tracking(1)
                                        .foregroundColor(.black)
                                        .padding(.horizontal, 24)
                                        .padding(.bottom, 16)
                                    
                                    HStack(spacing: 12) {
                                        Button(action: { if qty > 1 { qty -= 1 } }) {
                                            Image(systemName: "minus.circle")
                                                .font(.system(size: 20, weight: .light))
                                                .foregroundColor(.black.opacity(0.4))
                                        }
                                        
                                        TextField("Qty", value: $qty, format: .number)
                                            .font(.system(size: 16, weight: .semibold, design: .default))
                                            .multilineTextAlignment(.center)
                                            .keyboardType(.numberPad)
                                            .frame(maxWidth: .infinity)
                                            .foregroundColor(.black)
                                        
                                        Button(action: { qty += 1 }) {
                                            Image(systemName: "plus.circle")
                                                .font(.system(size: 20, weight: .light))
                                                .foregroundColor(.black.opacity(0.4))
                                        }
                                    }
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(Color.black.opacity(0.02))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 0)
                                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                                    )
                                    .padding(.horizontal, 24)
                                    .padding(.bottom, 28)
                                }
                                
                                // Rate Section
                                VStack(alignment: .leading, spacing: 0) {
                                    Text("UNIT PRICE")
                                        .font(.system(size: 11, weight: .semibold, design: .default))
                                        .tracking(1)
                                        .foregroundColor(.black)
                                        .padding(.horizontal, 24)
                                        .padding(.bottom, 16)
                                    
                                    HStack(spacing: 8) {
                                        Text("₹")
                                            .font(.system(size: 14, weight: .light, design: .default))
                                            .foregroundColor(.gray)
                                        
                                        TextField("0.00", value: $rate, format: .number)
                                            .font(.system(size: 15, weight: .light, design: .default))
                                            .keyboardType(.decimalPad)
                                            .frame(maxWidth: .infinity)
                                            .foregroundColor(.black)
                                    }
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(Color.black.opacity(0.02))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 0)
                                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                                    )
                                    .padding(.horizontal, 24)
                                    .padding(.bottom, 28)
                                }
                                
                                // Discount Section
                                VStack(alignment: .leading, spacing: 0) {
                                    Text("DISCOUNT")
                                        .font(.system(size: 11, weight: .semibold, design: .default))
                                        .tracking(1)
                                        .foregroundColor(.black)
                                        .padding(.horizontal, 24)
                                        .padding(.bottom, 16)
                                    
                                    HStack(spacing: 8) {
                                        Text("₹")
                                            .font(.system(size: 14, weight: .light, design: .default))
                                            .foregroundColor(.gray)
                                        
                                        TextField("0.00", value: $discount, format: .number)
                                            .font(.system(size: 15, weight: .light, design: .default))
                                            .keyboardType(.decimalPad)
                                            .frame(maxWidth: .infinity)
                                            .foregroundColor(.black)
                                    }
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(Color.black.opacity(0.02))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 0)
                                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                                    )
                                    .padding(.horizontal, 24)
                                    .padding(.bottom, 28)
                                }
                                
                                // Tax Rate Section
                                VStack(alignment: .leading, spacing: 0) {
                                    Text("TAX RATE")
                                        .font(.system(size: 11, weight: .semibold, design: .default))
                                        .tracking(1)
                                        .foregroundColor(.black)
                                        .padding(.horizontal, 24)
                                        .padding(.bottom, 16)
                                    
                                    Picker("Tax", selection: $taxRate) {
                                        Text("0%").tag(0.0)
                                        Text("5%").tag(5.0)
                                        Text("9%").tag(9.0)
                                        Text("12%").tag(12.0)
                                        Text("18%").tag(18.0)
                                        Text("28%").tag(28.0)
                                    }
                                    .pickerStyle(.segmented)
                                    .padding(.horizontal, 24)
                                    .padding(.bottom, 28)
                                }
                                
                                // Summary Section
                                VStack(alignment: .leading, spacing: 0) {
                                    Text("SUMMARY")
                                        .font(.system(size: 11, weight: .semibold, design: .default))
                                        .tracking(1)
                                        .foregroundColor(.black)
                                        .padding(.horizontal, 24)
                                        .padding(.bottom, 16)
                                    
                                    VStack(spacing: 0) {
                                        SummaryLineZara(label: "Subtotal", value: subtotal)
                                        
                                        Divider()
                                            .frame(height: 1)
                                            .background(Color.black.opacity(0.08))
                                            .padding(.horizontal, 24)
                                        
                                        if taxRate > 0 {
                                            SummaryLineZara(label: "Tax (\(String(format: "%.0f", taxRate))%)", value: taxAmount)
                                            
                                            Divider()
                                                .frame(height: 1)
                                                .background(Color.black.opacity(0.08))
                                                .padding(.horizontal, 24)
                                        }
                                        
                                        SummaryLineZara(label: "Total", value: total, isTotal: true)
                                    }
                                    .padding(.horizontal, 24)
                                    .padding(.bottom, 100)
                                }
                            }
                        }
                    }
                    
                    // Floating Save Button
                    VStack {
                        Spacer()
                        
                        VStack(spacing: 12) {
                            Button(action: {
                                var updatedItem = currentItem
                                updatedItem.qty = qty
                                updatedItem.rate = rate
                                updatedItem.discount = discount
                                updatedItem.taxRate = taxRate
                                
                                if let index = invoiceItems.firstIndex(where: { $0.id == currentItem.id }) {
                                    invoiceItems[index] = updatedItem
                                }
                                
                                item = nil
                                isPresented = false
                                dismiss()
                            }) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 12, weight: .semibold))
                                    Text("SAVE CHANGES")
                                        .font(.system(size: 12, weight: .semibold, design: .default))
                                        .tracking(0.5)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.black)
                                .foregroundColor(.white)
                            }
                            
                            Button(action: {
                                item = nil
                                isPresented = false
                                dismiss()
                            }) {
                                Text("CANCEL")
                                    .font(.system(size: 12, weight: .semibold, design: .default))
                                    .tracking(0.5)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .foregroundColor(.black)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 0)
                                            .stroke(Color.black, lineWidth: 1)
                                    )
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(Color.white)
                        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: -4)
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                qty = item?.qty ?? 1
                rate = item?.rate ?? 0
                discount = item?.discount ?? 0
                taxRate = item?.taxRate ?? 18
            }
        }
    }
}

// MARK: - Summary Line (Zara Style)
struct SummaryLineZara: View {
    let label: String
    let value: Double
    var isTotal: Bool = false
    
    var body: some View {
        HStack(spacing: 0) {
            Text(label)
                .font(.system(size: isTotal ? 13 : 11, weight: isTotal ? .semibold : .light, design: .default))
                .foregroundColor(.black)
            
            Spacer()
            
            Text("₹\(String(format: "%.2f", value))")
                .font(.system(size: isTotal ? 13 : 11, weight: isTotal ? .semibold : .light, design: .default))
                .foregroundColor(.black)
        }
        .padding(.horizontal, 0)
        .padding(.vertical, 10)
    }
}
