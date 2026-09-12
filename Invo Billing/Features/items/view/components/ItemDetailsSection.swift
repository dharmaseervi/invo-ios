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


    enum FocusableField {
        case name, sku, description, unit, category
    }


    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Item details")
                .font(.scaled(13, weight: .medium))
                .foregroundColor(.sMutedFG)
                .padding(.horizontal, 20)

            VStack(spacing: 12) {
                FormField(
                    title: "Item name",
                    placeholder: "Enter item name",
                    text: $vm.name,
                    error: vm.name.isEmpty ? "Required" : nil,
                    focused: focusedField == .name
                )
                .focused($focusedField, equals: .name)

                VStack(alignment: .leading, spacing: 6) {
                    Text("SKU / Barcode")
                        .font(.scaled(13, weight: .medium))
                        .foregroundColor(.sForeground)

                    HStack(spacing: 8) {
                        TextField("Product code", text: $vm.sku)
                            .font(.scaled(14))
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
                                .font(.scaled(12, weight: .medium))
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
                            .font(.scaled(13, weight: .medium))
                            .foregroundColor(.sForeground)
                        Spacer()
                        Text("GST")
                            .font(.scaled(10))
                            .foregroundColor(.sMutedFG)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.sMuted)
                            .cornerRadius(4)
                    }

                    TextField("e.g. 1234", text: $vm.hsnCode)
                        .font(.scaled(14))
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

                HStack(spacing: 10) {
                    UnitPicker(selectedUnit: $vm.unit)
                    CategoryPicker(vm: vm)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Description")
                        .font(.scaled(13, weight: .medium))
                        .foregroundColor(.sForeground)

                    TextEditor(text: $vm.description)
                        .font(.scaled(14))
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
            .padding(.horizontal, 20)
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
                .font(.scaled(13, weight: .medium))
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
                        .font(.scaled(13))
                        .foregroundColor(selectedUnit == nil ? .sMutedFG : .sForeground)

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.scaled(11, weight: .medium))
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
                .font(.scaled(13, weight: .medium))
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
                    .font(.scaled(13))
                    .foregroundColor(vm.selectedCategoryId == nil ? .sMutedFG : .sForeground)
                    .lineLimit(1)

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.scaled(11, weight: .medium))
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
