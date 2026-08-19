//
//  PricingStockSection.swift
//  invo
//
//  Created by dharmaseervi on 11/23/25.
//

import SwiftUI

struct PricingStockSection: View {
    @ObservedObject var vm: ItemViewModel
    @FocusState private var focusedField: PricingFormField?
    
    enum PricingFormField {
        case costPrice, sellingPrice, stock, lowAlert, taxRate
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("PRICING & INVENTORY")
                .font(.system(size: 11, weight: .semibold, design: .default))
                .tracking(1)
                .foregroundColor(.black)
                .padding(.horizontal, 24)
                .padding(.top, 32)
                .padding(.bottom, 20)
            
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    FormFieldHalf(
                        title: "Cost Price",
                        placeholder: "₹0.00",
                        text: $vm.costPrice,
                        keyboardType: .decimalPad,
                        focused: focusedField == .costPrice
                    )
                    .focused($focusedField, equals: .costPrice)
                    
                    Divider()
                        .frame(width: 1)
                        .background(Color.black.opacity(0.08))
                    
                    FormFieldHalf(
                        title: "Selling Price",
                        placeholder: "₹0.00",
                        text: $vm.price,
                        keyboardType: .decimalPad,
                        focused: focusedField == .sellingPrice
                    )
                    .focused($focusedField, equals: .sellingPrice)
                }
                
                Divider()
                    .frame(height: 1)
                    .background(Color.black.opacity(0.08))
                    .padding(.horizontal, 24)
                
                HStack(spacing: 0) {
                    FormFieldHalf(
                        title: "Stock Quantity",
                        placeholder: "0",
                        text: $vm.quantity,
                        keyboardType: .numberPad,
                        focused: focusedField == .stock
                    )
                    .focused($focusedField, equals: .stock)
                    
                    Divider()
                        .frame(width: 1)
                        .background(Color.black.opacity(0.08))
                    
                    FormFieldHalf(
                        title: "Low Stock Alert",
                        placeholder: "Min qty",
                        text: $vm.lowStockAlert,
                        keyboardType: .numberPad,
                        focused: focusedField == .lowAlert
                    )
                    .focused($focusedField, equals: .lowAlert)
                }
                
                Divider()
                    .frame(height: 1)
                    .background(Color.black.opacity(0.08))
                    .padding(.horizontal, 24)
                
                FormField(
                    title: "Tax Rate (%)",
                    placeholder: "e.g. 18",
                    text: $vm.taxRate,
                    keyboardType: .decimalPad,
                    focused: focusedField == .taxRate
                )
                .focused($focusedField, equals: .taxRate)
            }
        }
    }
}


// MARK: - Zara Form Field
struct FormField: View {
    let title: String
    var placeholder: String = ""
    @Binding var text: String
    var error: String? = nil
    var keyboardType: UIKeyboardType = .default
    var focused: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.system(size: 10, weight: .regular, design: .default))
                        .foregroundColor(.gray)
                        .tracking(0.3)
                    
                    TextField(placeholder, text: $text)
                        .keyboardType(keyboardType)
                        .font(.system(size: 15, weight: .light, design: .default))
                        .foregroundColor(.black)
                        .autocorrectionDisabled()
                }
                
                if error != nil {
                    Image(systemName: "exclamationmark")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            
            if let error = error {
                Text(error)
                    .font(.system(size: 9, weight: .regular, design: .default))
                    .foregroundColor(.red)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
            }
        }
    }
}

// MARK: - Zara Form Field Half Width
struct FormFieldHalf: View {
    let title: String
    var placeholder: String = ""
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var focused: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 10, weight: .regular, design: .default))
                    .foregroundColor(.gray)
                    .tracking(0.3)
                
                TextField(placeholder, text: $text)
                    .keyboardType(keyboardType)
                    .font(.system(size: 15, weight: .light, design: .default))
                    .foregroundColor(.black)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
    }
}
