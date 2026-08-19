//
//  EditInvoiceItemSheet.swift
//  invo
//
//  Created by dharmaseervi on 11/25/25.
//
import SwiftUI

struct EditInvoiceItemSheet: View {
    @Binding var lineItem: InvoiceLineItem
    @Environment(\.dismiss) var dismiss
    
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(lineItem.item.name).bold()) {
                    
                    Stepper("Quantity: \(lineItem.qty)") {
                        lineItem.qty += 1
                    } onDecrement: {
                        if lineItem.qty > 1 { lineItem.qty -= 1 }
                    }

                    TextField("Rate", value: $lineItem.rate, format: .number)
                        .keyboardType(.decimalPad)
                    
                    TextField("Discount", value: $lineItem.discount, format: .number)
                        .keyboardType(.decimalPad)
                    
                    Picker("Tax", selection: $lineItem.taxRate) {
                        ForEach([0, 5, 12, 18, 28], id: \.self) { tax in
                            Text("\(tax)%").tag(Double(tax))
                        }
                    }
                }
                
                Section(header: Text("Totals")) {
                    HStack {
                        Text("Sub-Total")
                        Spacer()
                        Text("₹\(lineItem.totalBeforeTax, specifier: "%.2f")")
                    }
                    HStack {
                        Text("Tax")
                        Spacer()
                        Text("₹\(lineItem.taxAmount, specifier: "%.2f")")
                    }
                    HStack {
                        Text("Grand Total").bold()
                        Spacer()
                        Text("₹\(lineItem.total, specifier: "%.2f")").bold()
                    }
                }
            }
            .navigationTitle("Edit Item")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Save") { dismiss() }
                }
            }
        }
    }
}
