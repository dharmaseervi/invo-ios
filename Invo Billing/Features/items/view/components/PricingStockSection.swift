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
        VStack(alignment: .leading, spacing: 14) {
            Text("Pricing & inventory")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.sMutedFG)
                .padding(.horizontal, 20)

            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    FormFieldHalf(
                        title: "Cost price",
                        placeholder: "₹0.00",
                        text: $vm.costPrice,
                        keyboardType: .decimalPad,
                        focused: focusedField == .costPrice
                    )
                    .focused($focusedField, equals: .costPrice)

                    FormFieldHalf(
                        title: "Selling price",
                        placeholder: "₹0.00",
                        text: $vm.price,
                        keyboardType: .decimalPad,
                        focused: focusedField == .sellingPrice
                    )
                    .focused($focusedField, equals: .sellingPrice)
                }

                HStack(spacing: 10) {
                    FormFieldHalf(
                        title: "Stock quantity",
                        placeholder: "0",
                        text: $vm.quantity,
                        keyboardType: .numberPad,
                        focused: focusedField == .stock
                    )
                    .focused($focusedField, equals: .stock)

                    FormFieldHalf(
                        title: "Low stock alert",
                        placeholder: "Min qty",
                        text: $vm.lowStockAlert,
                        keyboardType: .numberPad,
                        focused: focusedField == .lowAlert
                    )
                    .focused($focusedField, equals: .lowAlert)
                }

                FormField(
                    title: "Tax rate (%)",
                    placeholder: "e.g. 18",
                    text: $vm.taxRate,
                    keyboardType: .decimalPad,
                    focused: focusedField == .taxRate
                )
                .focused($focusedField, equals: .taxRate)
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 20)
    }
}


// MARK: - Form Field
struct FormField: View {
    let title: String
    var placeholder: String = ""
    @Binding var text: String
    var error: String? = nil
    var keyboardType: UIKeyboardType = .default
    var focused: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.sForeground)
                if error != nil {
                    Image(systemName: "exclamationmark.circle")
                        .font(.system(size: 12))
                        .foregroundColor(.sDestructive)
                }
            }

            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .font(.system(size: 14))
                .foregroundColor(.sForeground)
                .tint(.sAccent)
                .autocorrectionDisabled()
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.sCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(error != nil ? Color.sDestructive.opacity(0.5) : Color.sInput, lineWidth: 0.5)
                )
                .cornerRadius(8)

            if let error = error {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundColor(.sDestructive)
            }
        }
    }
}

// MARK: - Form Field Half Width
struct FormFieldHalf: View {
    let title: String
    var placeholder: String = ""
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var focused: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.sForeground)

            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .font(.system(size: 14))
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
