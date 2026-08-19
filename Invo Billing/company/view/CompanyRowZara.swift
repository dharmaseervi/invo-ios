//
//  CompanyRowZara.swift
//  Invo Billing
//
//  Created by dharmaseervi on 2/5/26.
//

import SwiftUI


struct CompanyRowBank: View {
    let company: CompanyResponse
    let isSelected: Bool
    let onSelect: () -> Void
    let onManageBank: () -> Void   // NEW
    
    var body: some View {
        HStack(spacing: 16) {
            Button(action: onSelect) {
                rowContent
            }
            .buttonStyle(.plain)

            Button(action: onManageBank) {
                Image(systemName: "building.columns")
                    .font(.system(size: 15))
                    .foregroundColor(.black.opacity(0.7))
                    .frame(width: 36, height: 36)
                    .background(Color.black.opacity(0.05))
                    .cornerRadius(8)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
    }
    
    private var rowContent: some View {
        HStack(spacing: 16) {
            avatar
            companyInfo
            Spacer()
            selectionIndicator
        }
    }
    
    private var avatar: some View {
        Text(String(company.name.prefix(1)).uppercased())
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.white)
            .frame(width: 44, height: 44)
            .background(Color.black)
            .cornerRadius(6)
    }
    
    private var companyInfo: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(company.name)
                .font(.system(size: 13, weight: .semibold))
            
            Text("\(company.city), \(company.state)")
                .font(.system(size: 11, weight: .light))
                .foregroundColor(.gray)
        }
    }
    
    private var selectionIndicator: some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .foregroundColor(isSelected ? .black : .gray.opacity(0.4))
    }
}
