//
//  ItemDetailsSection.swift
//  invo
//
//  Created by dharmaseervi on 11/23/25.
//

import SwiftUI

// MARK: - Item Details Section
struct ItemDetailsSection: View {
    @ObservedObject var vm: ItemViewModel
    @FocusState private var focusedField: FocusableField?
    @State private var showBarcodeScanner = false

    enum FocusableField {
        case name, sku, description, unit, category
    }


    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Item details")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.sMutedFG)
                .padding(.horizontal, AppSpacing.page)

            VStack(spacing: 12) {
                FormField(
                    title: "Item name (required)",
                    placeholder: "Enter item name",
                    text: $vm.name,
                    error: nil,
                    focused: focusedField == .name
                )
                .focused($focusedField, equals: .name)

                VStack(alignment: .leading, spacing: 6) {
                    Text("SKU / Barcode")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.sForeground)

                    HStack(spacing: 8) {
                        TextField("Product code", text: $vm.sku)
                            .font(.body)
                            .foregroundColor(.sForeground)
                            .tint(.sAccent)
                            .autocorrectionDisabled()
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.sCard)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.sInput, lineWidth: 0.5)
                            )
                            .cornerRadius(8)
                            .focused($focusedField, equals: .sku)

                        Button {
                            vm.sku = ItemViewModel.generateSKU()
                        } label: {
                            Text("Generate")
                                .font(.footnote.weight(.medium))
                                .foregroundColor(.sAccent)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Color.sAccentMuted)
                                .cornerRadius(8)
                        }
                    }
                }

                // HSN Code field
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("HSN code")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.sForeground)
                        Spacer()
                        Text("GST")
                            .font(.caption)
                            .foregroundColor(.sMutedFG)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.sMuted)
                            .cornerRadius(4)
                    }

                    TextField("HSN code", text: $vm.hsnCode, prompt: Text("e.g. 1234"))
                        .font(.body)
                        .foregroundColor(.sForeground)
                        .tint(.sAccent)
                        .keyboardType(.numberPad)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.sCard)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.sInput, lineWidth: 0.5)
                        )
                        .cornerRadius(8)
                }

                // Barcode field
                VStack(alignment: .leading, spacing: 6) {
                    Text("Barcode")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.sForeground)

                    HStack(spacing: 8) {
                        TextField("Scan or enter barcode", text: $vm.barcode)
                            .font(.body)
                            .foregroundColor(.sForeground)
                            .tint(.sAccent)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.sCard)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.sInput, lineWidth: 0.5))
                            .cornerRadius(8)

                        Button {
                            showBarcodeScanner = true
                        } label: {
                            Image(systemName: "barcode.viewfinder")
                                .font(.title3)
                                .foregroundColor(.sAccent)
                                .frame(width: 44, height: 44)
                                .background(Color.sCard)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.sInput, lineWidth: 0.5))
                                .cornerRadius(8)
                        }
                        .accessibilityLabel("Scan barcode")
                    }
                }
                .sheet(isPresented: $showBarcodeScanner) {
                    ItemScannerView(onCancel: { showBarcodeScanner = false }) { code in
                        vm.barcode = code
                        showBarcodeScanner = false
                    }
                    .ignoresSafeArea()
                }

                // Side by side while they fit, stacked when they do not: at a large
                // text size Unit wrapped to two lines while Category truncated to
                // "Select c…", so the pair behaved two different ways in one row.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        UnitPicker(selectedUnit: $vm.unit)
                        CategoryPicker(vm: vm)
                    }
                    VStack(spacing: 14) {
                        UnitPicker(selectedUnit: $vm.unit)
                        CategoryPicker(vm: vm)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Description")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.sForeground)

                    TextEditor(text: $vm.description)
                        .accessibilityLabel("Item description")
                        .font(.body)
                        .foregroundColor(.sForeground)
                        .scrollContentBackground(.hidden)
                        .frame(height: 80)
                        .padding(8)
                        .background(Color.sCard)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.sInput, lineWidth: 0.5)
                        )
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, AppSpacing.page)
        }
        .padding(.top, 20)
    }
}

struct UnitPicker: View {
    @Binding var selectedUnit: String?

    let units = [
        "Pieces", "Box", "Pair", "Set", "Dozen",
        "Kg", "Gram", "Liter", "ML",
        "Meter", "Feet", "Roll",
        "Bag", "Packet", "Carton", "Bundle",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Unit")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.sForeground)

            Menu {
                ForEach(units, id: \.self) { unit in
                    Button {
                        selectedUnit = unit
                    } label: {
                        Text(unit)
                    }
                }
            } label: {
                HStack {
                    Text(selectedUnit ?? "Select unit")
                        .font(.subheadline)
                        .foregroundColor(selectedUnit == nil ? .sMutedFG : .sForeground)

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.sMutedFG)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.sCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.sInput, lineWidth: 0.5)
                )
                .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}


struct CategoryPicker: View {
    @ObservedObject var vm: ItemViewModel
    @State private var showAddCategory = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Category")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.sForeground)

            Menu {
                ForEach(vm.categories) { cat in
                    Button {
                        vm.selectedCategoryId = cat.id
                        vm.applyCategoryDefaults(cat)
                    } label: {
                        Text(cat.name)
                    }
                }

                Divider()

                Button {
                    showAddCategory = true
                } label: {
                    Label("Add new category", systemImage: "plus")
                }
            } label: {
                HStack {
                    Text(
                        vm.selectedCategoryId != nil
                        ? (vm.categories.first(where: {
                            $0.id == vm.selectedCategoryId
                        })?.name ?? "Select category")
                        : "Select category"
                    )
                    .font(.subheadline)
                    .foregroundColor(vm.selectedCategoryId == nil ? .sMutedFG : .sForeground)
                    .lineLimit(1)

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.sMutedFG)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.sCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.sInput, lineWidth: 0.5)
                )
                .cornerRadius(8)
            }
            .sheet(isPresented: $showAddCategory, onDismiss: {
                Task {
                    await vm.loadCategories()
                    if let newest = vm.categories.last {
                        vm.selectedCategoryId = newest.id
                    }
                }
            }) {
                AddCategorySheet(vm: vm)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task {
            await vm.loadCategories()
        }
    }
}
