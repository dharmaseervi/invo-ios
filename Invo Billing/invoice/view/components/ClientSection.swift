//
//  ClientSection.swift
//  invo
//
//  Created by dharmaseervi on 11/25/25.
//

import SwiftUI

struct ClientSection: View {
    let selectedClient: ClientModel?
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("CLIENT")
                .font(.system(size: 11, weight: .semibold, design: .default))
                .tracking(1)
                .foregroundColor(.black)
                .padding(.horizontal, 24)
                .padding(.top, 28)
                .padding(.bottom, 16)
            
            Button(action: onTap) {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        if let client = selectedClient {
                            Text(client.name)
                                .font(.system(size: 14, weight: .semibold, design: .default))
                                .foregroundColor(.black)
                            
                            Text(client.email.isEmpty ? client.phone : client.email)
                                .font(.system(size: 12, weight: .light, design: .default))
                                .foregroundColor(.gray)
                                .lineLimit(1)
                        } else {
                            Text("Select Client")
                                .font(.system(size: 14, weight: .light, design: .default))
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.black.opacity(0.3))
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(Color.black.opacity(0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 0)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
    }
}
