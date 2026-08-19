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
        VStack(alignment: .leading, spacing: 0) {
            Text("ITEM DETAILS")
                .font(.system(size: 11, weight: .semibold, design: .default))
                .tracking(1)
                .foregroundColor(.black)
                .padding(.horizontal, 24)
                .padding(.top, 28)
                .padding(.bottom, 20)
            
            VStack(spacing: 0) {
                FormField(
                    title: "Item Name",
                    placeholder: "Enter item name",
                    text: $vm.name,
                    error: vm.name.isEmpty ? "Required" : nil,
                    focused: focusedField == .name
                )
                .focused($focusedField, equals: .name)
                
                Divider()
                    .frame(height: 1)
                    .background(Color.black.opacity(0.08))
                    .padding(.horizontal, 24)
                
              
                    FormFieldHalf(
                        title: "SKU / Barcode",
                        placeholder: "Product code",
                        text: $vm.sku,
                        focused: focusedField == .sku
                    )
                    .focused($focusedField, equals: .sku)
                    
                // In ItemDetailsSection, add after SKU field:
                
                Divider()
                    .frame(height: 1)
                    .background(Color.black.opacity(0.08))
                    .padding(.horizontal, 24)
                
                // HSN Code field
                VStack(alignment: .leading, spacing: 8) {
                    Text("HSN CODE")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(.gray)
                        .tracking(0.3)
                    
                    HStack {
                        TextField("e.g. 1234", text: $vm.hsnCode)
                            .font(.system(size: 15, weight: .light))
                            .foregroundColor(.black)
                            .keyboardType(.numberPad)
                            .autocorrectionDisabled()
                        
                        Spacer()
                        
                        Text("GST")
                            .font(.system(size: 9, weight: .regular))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.black.opacity(0.05))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                
                Divider()
                    .frame(height: 1)
                    .background(Color.black.opacity(0.08))
                    .padding(.horizontal, 24)
                
                HStack(spacing: 0) {
                    UnitPicker(selectedUnit: $vm.unit)
                    
                    Divider()
                        .frame(width: 1)
                        .background(Color.black.opacity(0.08))
                    
                    CategoryPicker(vm: vm)
                }
                
                Divider()
                    .frame(height: 1)
                    .background(Color.black.opacity(0.08))
                    .padding(.horizontal, 24)
                
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.system(size: 10, weight: .regular, design: .default))
                            .foregroundColor(.gray)
                            .tracking(0.3)
                        
                        TextEditor(text: $vm.description)
                            .font(.system(size: 13, weight: .light, design: .default))
                            .frame(height: 80)
                            .padding(8)
                            .background(Color.black.opacity(0.02))
                            .overlay(
                                RoundedRectangle(cornerRadius: 0)
                                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
                            )
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                }
            }
        }
    }
}

struct UnitPicker: View {
    @Binding var selectedUnit: String?
    
    let units = ["Pieces", "Box", "Kg", "Liter", "Bag"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("UNIT")
                .font(.system(size: 10, weight: .medium))
                .tracking(0.6)
                .foregroundColor(.gray)
    
            
            Menu {
                ForEach(units, id: \.self) { unit in
                    Button {
                        selectedUnit = unit
                    } label: {
                        Text(unit.uppercased())
                    }
                }
            } label: {
                HStack {
                    Text(selectedUnit?.uppercased() ?? "SELECT UNIT")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(selectedUnit == nil ? .gray : .black)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.black)
                }
         
            }
        } .padding(.vertical, 14)
            .padding(.horizontal, 20)
    }
}


struct CategoryPicker: View {
    @ObservedObject var vm: ItemViewModel
    @State private var showAddCategory = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("CATEGORY")
                .font(.system(size: 10, weight: .medium))
                .tracking(0.6)
                .foregroundColor(.gray)
            
            Menu {
                ForEach(vm.categories) { cat in
                    Button {
                        vm.selectedCategoryId = cat.id
                    } label: {
                        Text(cat.name.uppercased())
                    }
                }
                
                Divider()
                
                Button {
                    showAddCategory = true
                } label: {
                    Label("ADD NEW CATEGORY", systemImage: "plus")
                }
            } label: {
                HStack {
                    Text(
                        vm.selectedCategoryId != nil
                        ? (vm.categories.first(where: {
                            $0.id == vm.selectedCategoryId
                        })?.name.uppercased() ?? "SELECT CATEGORY")
                        : "SELECT CATEGORY"
                    )
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(vm.selectedCategoryId == nil ? .gray : .black)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.black)
                }
            }
            // ✅ Reload categories when sheet dismisses
            .sheet(isPresented: $showAddCategory, onDismiss: {
                Task {
                    await vm.loadCategories()
                    // ✅ Auto-select the newly created category
                    if let newest = vm.categories.last {
                        vm.selectedCategoryId = newest.id
                    }
                }
            }) {
                AddCategorySheet(vm: vm)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 20)
        .task {
            await vm.loadCategories()
        }
    }
}

