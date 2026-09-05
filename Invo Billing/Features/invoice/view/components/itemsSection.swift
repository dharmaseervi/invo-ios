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
            Text("Items")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.sMutedFG)
                .padding(.horizontal, 20)
                .padding(.bottom, 10)

            if invoiceItems.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "box.2")
                        .font(.system(size: 32))
                        .foregroundColor(.sMutedFG)
                    VStack(spacing: 4) {
                        Text("No items added")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.sForeground)
                        Text("Add items to create your invoice")
                            .font(.system(size: 12))
                            .foregroundColor(.sMutedFG)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .background(Color.sCard)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.sBorder, lineWidth: 0.5))
                .cornerRadius(10)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            } else {
                VStack(spacing: 8) {
                    HStack {
                        Text("Total items")
                            .font(.system(size: 12))
                            .foregroundColor(.sMutedFG)
                        Spacer()
                        Text("\(totalItems)")
                            .font(.system(size: 13))
                            .foregroundColor(.sForeground)
                    }

                    Rectangle().fill(Color.sBorder).frame(height: 0.5)

                    HStack {
                        Text("Total amount")
                            .font(.system(size: 12))
                            .foregroundColor(.sMutedFG)
                        Spacer()
                        Text("₹\(String(format: "%.2f", totalAmount))")
                            .font(.system(size: 13))
                            .foregroundColor(.sForeground)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.sCard)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.sBorder, lineWidth: 0.5))
                .cornerRadius(10)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

                VStack(spacing: 10) {
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
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }

            // Add Item Buttons
            VStack(spacing: 8) {
                Button(action: { showItemPicker = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Add item")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundColor(.sForeground)
                    .background(Color.sCard)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.sBorder, lineWidth: 0.5))
                    .cornerRadius(10)
                }

                Button(action: { showScanner = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "barcode.viewfinder")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Scan item")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundColor(.sForeground)
                    .background(Color.sCard)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.sBorder, lineWidth: 0.5))
                    .cornerRadius(10)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
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
        HStack(spacing: 12) {
            Text(String(item.item.name.prefix(1)).uppercased())
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.sAccentFG)
                .frame(width: 40, height: 40)
                .background(Color.sAccent)
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.item.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.sForeground)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text("Qty: \(item.qty)")
                        .font(.system(size: 11))
                        .foregroundColor(.sMutedFG)
                    Text("•")
                        .foregroundColor(.sMutedFG)
                    Text("₹\(String(format: "%.2f", item.rate))")
                        .font(.system(size: 11))
                        .foregroundColor(.sMutedFG)

                    if item.discount > 0 {
                        Text("•")
                            .foregroundColor(.sMutedFG)
                        Text("Disc: ₹\(String(format: "%.2f", item.discount))")
                            .font(.system(size: 11))
                            .foregroundColor(.sMutedFG)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                Text("₹\(String(format: "%.2f", item.total))")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.sForeground)

                HStack(spacing: 14) {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.system(size: 12))
                            .foregroundColor(.sMutedFG)
                    }
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundColor(.sDestructive)
                    }
                }
            }
        }
        .padding(12)
        .background(Color.sCard)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.sBorder, lineWidth: 0.5))
        .cornerRadius(10)
    }
}

// MARK: - Edit Item Sheet
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
        max((rate * Double(qty)) - discount, 0)
    }

    var taxAmount: Double {
        subtotal * (taxRate / 100)
    }

    var total: Double {
        subtotal + taxAmount
    }

    var isValid: Bool {
        qty >= 1 && rate >= 0 && discount >= 0
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.sBackground.ignoresSafeArea()

                if let currentItem = item {
                    VStack(spacing: 0) {
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 20) {

                                // Item Display
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Item")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.sMutedFG)

                                    HStack(spacing: 12) {
                                        Text(String(currentItem.item.name.prefix(1)).uppercased())
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.sAccentFG)
                                            .frame(width: 44, height: 44)
                                            .background(Color.sAccent)
                                            .cornerRadius(10)

                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(currentItem.item.name)
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(.sForeground)

                                            if let desc = currentItem.item.description {
                                                Text(desc)
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.sMutedFG)
                                                    .lineLimit(1)
                                            }
                                        }
                                        Spacer()
                                    }
                                    .padding(12)
                                    .background(Color.sCard)
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.sBorder, lineWidth: 0.5))
                                    .cornerRadius(10)
                                }

                                // Quantity
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Quantity")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.sMutedFG)

                                    HStack(spacing: 12) {
                                        Button(action: { if qty > 1 { qty -= 1 } }) {
                                            Image(systemName: "minus.circle")
                                                .font(.system(size: 20))
                                                .foregroundColor(.sMutedFG)
                                        }

                                        TextField("Qty", value: $qty, format: .number)
                                            .font(.system(size: 16, weight: .semibold))
                                            .multilineTextAlignment(.center)
                                            .keyboardType(.numberPad)
                                            .frame(maxWidth: .infinity)
                                            .foregroundColor(.sForeground)

                                        Button(action: { qty += 1 }) {
                                            Image(systemName: "plus.circle")
                                                .font(.system(size: 20))
                                                .foregroundColor(.sMutedFG)
                                        }
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .background(Color.sCard)
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.sBorder, lineWidth: 0.5))
                                    .cornerRadius(10)
                                }

                                // Rate
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Unit price")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.sMutedFG)

                                    HStack(spacing: 8) {
                                        Text("₹")
                                            .font(.system(size: 14))
                                            .foregroundColor(.sMutedFG)

                                        TextField("0.00", value: $rate, format: .number)
                                            .font(.system(size: 15))
                                            .keyboardType(.decimalPad)
                                            .frame(maxWidth: .infinity)
                                            .foregroundColor(.sForeground)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .background(Color.sCard)
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.sBorder, lineWidth: 0.5))
                                    .cornerRadius(10)
                                }

                                // Discount
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Discount")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.sMutedFG)

                                    HStack(spacing: 8) {
                                        Text("₹")
                                            .font(.system(size: 14))
                                            .foregroundColor(.sMutedFG)

                                        TextField("0.00", value: $discount, format: .number)
                                            .font(.system(size: 15))
                                            .keyboardType(.decimalPad)
                                            .frame(maxWidth: .infinity)
                                            .foregroundColor(.sForeground)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .background(Color.sCard)
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.sBorder, lineWidth: 0.5))
                                    .cornerRadius(10)
                                }

                                // Tax Rate
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Tax rate")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.sMutedFG)

                                    Picker("Tax", selection: $taxRate) {
                                        Text("0%").tag(0.0)
                                        Text("5%").tag(5.0)
                                        Text("9%").tag(9.0)
                                        Text("12%").tag(12.0)
                                        Text("18%").tag(18.0)
                                        Text("28%").tag(28.0)
                                    }
                                    .pickerStyle(.segmented)
                                }

                                // Summary
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Summary")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.sMutedFG)

                                    VStack(spacing: 0) {
                                        SummaryLineZara(label: "Subtotal", value: subtotal)

                                        Rectangle().fill(Color.sBorder).frame(height: 0.5).padding(.horizontal, 14)

                                        if taxRate > 0 {
                                            SummaryLineZara(label: "Tax (\(String(format: "%.0f", taxRate))%)", value: taxAmount)
                                            Rectangle().fill(Color.sBorder).frame(height: 0.5).padding(.horizontal, 14)
                                        }

                                        SummaryLineZara(label: "Total", value: total, isTotal: true)
                                    }
                                    .background(Color.sCard)
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.sBorder, lineWidth: 0.5))
                                    .cornerRadius(10)
                                }
                                .padding(.bottom, 100)
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                        }
                    }

                    // Floating Save Button
                    VStack {
                        Spacer()

                        VStack(spacing: 10) {
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
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 13, weight: .semibold))
                                    Text("Save changes")
                                        .font(.system(size: 15, weight: .semibold))
                                }
                                .foregroundColor(.sAccentFG)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(isValid ? Color.sPrimary : Color.sPrimary.opacity(0.4))
                                .cornerRadius(10)
                            }
                            .disabled(!isValid)

                            Button(action: {
                                item = nil
                                isPresented = false
                                dismiss()
                            }) {
                                Text("Cancel")
                                    .font(.system(size: 14, weight: .medium))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .foregroundColor(.sForeground)
                                    .background(Color.sCard)
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.sBorder, lineWidth: 0.5))
                                    .cornerRadius(10)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(Color.sBackground)
                        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: -4)
                    }
                }
            }
            .navigationTitle("Edit item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        item = nil
                        isPresented = false
                        dismiss()
                    }
                }
            }
            .onAppear {
                qty = item?.qty ?? 1
                rate = item?.rate ?? 0
                discount = item?.discount ?? 0
                taxRate = item?.taxRate ?? 18
            }
        }
    }
}

// MARK: - Summary Line
struct SummaryLineZara: View {
    let label: String
    let value: Double
    var isTotal: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            Text(label)
                .font(.system(size: isTotal ? 14 : 12, weight: isTotal ? .semibold : .regular))
                .foregroundColor(.sForeground)

            Spacer()

            Text("₹\(String(format: "%.2f", value))")
                .font(.system(size: isTotal ? 14 : 12, weight: isTotal ? .semibold : .regular))
                .foregroundColor(.sForeground)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}
