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
                .font(.scaled(13, weight: .medium))
                .foregroundColor(.sMutedFG)
                .padding(.horizontal, 20)

            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        FormFieldHalf(
                            title: "Cost price",
                            placeholder: "₹0.00",
                            text: $vm.costPrice,
                            keyboardType: .decimalPad,
                            focused: focusedField == .costPrice
                        )
                        .focused($focusedField, equals: .costPrice)

                        if let cost = Double(vm.costPrice), cost > 0 {
                            Text("Label code: \(CostPriceCoder.encode(cost))")
                                .font(.scaled(10))
                                .foregroundColor(.sMutedFG)
                        }
                    }

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

                TaxRatePicker(taxRate: $vm.taxRate)
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 20)
    }
}

// MARK: - Tax Rate Picker (GST slabs — 5%, 12%, 18% cover almost everything)
struct TaxRatePicker: View {
    @Binding var taxRate: String

    private let options = ["5", "12", "18"]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Tax rate (GST %)")
                .font(.scaled(13, weight: .medium))
                .foregroundColor(.sForeground)

            Menu {
                ForEach(options, id: \.self) { rate in
                    Button {
                        taxRate = rate
                    } label: {
                        if taxRate == rate {
                            Label("\(rate)%", systemImage: "checkmark")
                        } else {
                            Text("\(rate)%")
                        }
                    }
                }
            } label: {
                HStack {
                    Text(taxRate.isEmpty ? "Select" : "\(taxRate)%")
                        .font(.scaled(14))
                        .foregroundColor(.sForeground)

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
                    .font(.scaled(13, weight: .medium))
                    .foregroundColor(.sForeground)
                if error != nil {
                    Image(systemName: "exclamationmark.circle")
                        .font(.scaled(12))
                        .foregroundColor(.sDestructive)
                }
            }

            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .font(.scaled(14))
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
                    .font(.scaled(11))
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
                .font(.scaled(13, weight: .medium))
                .foregroundColor(.sForeground)

            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
