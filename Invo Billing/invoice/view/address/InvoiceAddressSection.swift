//
//  InvoiceAddressSection.swift
//  Invo Billing
//
//  Created by dharmaseervi on 12/21/25.
//
import SwiftUI

extension AddressFormModel {
    var isEmpty: Bool {
        line1.isEmpty && city.isEmpty && state.isEmpty
    }
}


struct InvoiceAddressSection: View {
    let title: String
    let address: AddressFormModel
    let onEdit: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(1)
            
            if address.isEmpty {
                Button(action: onEdit) {
                    HStack {
                        Text("Add address")
                            .font(.system(size: 13))
                        Spacer()
                        Image(systemName: "plus")
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    if !address.name.isEmpty {
                        Text(address.name)
                            .fontWeight(.medium)
                    }
                    
                    Text(address.line1)
                    
                    Text("\(address.city), \(address.state)")
                        .foregroundColor(.gray)
                }
                .font(.system(size: 13))
               
                
                Button("Edit") {
                    onEdit()
                }
                .font(.system(size: 12))
                
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
}
