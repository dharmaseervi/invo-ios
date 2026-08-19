//
//  InvoiceNumberSection.swift
//  invo
//
//  Created by dharmaseervi on 12/14/25.
//

import SwiftUI

struct InvoiceNumberSection: View {
    let invoiceNumber: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("INVOICE NUMBER")
                .font(.system(size: 11, weight: .semibold, design: .default))
                .tracking(1)
                .foregroundColor(.black)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(invoiceNumber)
                        .font(.system(size: 14, weight: .semibold, design: .default))
                        .foregroundColor(.black)
                }
                
                Spacer()
                
                Image(systemName: "doc.fill")
                    .font(.system(size: 16, weight: .light))
                    .foregroundColor(.black.opacity(0.3))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(Color.black.opacity(0.02))
            .overlay(
                RoundedRectangle(cornerRadius: 0)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
    }
}
