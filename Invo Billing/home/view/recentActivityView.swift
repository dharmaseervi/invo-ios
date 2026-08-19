//
//  recentActivityView.swift
//  invo
//
//  Created by dharmaseervi on 11/25/25.
//

import SwiftUI

// MARK: - Recent Activity

struct RecentActivitySection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Activity").padding(.horizontal ,20)

            VStack(spacing: 0) {
                ForEach(0..<5, id: \.self) { index in
                    let title = "Invoice #INV-00\(index + 1)"
                    let hours = 2 + index
                    let subtitle = "Client Name • \(hours) hours ago"
                    let amountValue = 1_500 + index * 500
                    let amount = "₹\(amountValue)"
                    let status = index % 3 == 0 ? "Paid" : "Pending"
                    let isLast = index == 4

                    ActivityRowView(
                        title: title,
                        subtitle: subtitle,
                        amount: amount,
                        status: status,
                        isLast: isLast
                    )
                }
            }
            .background(Color.red.opacity(0.05))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.gray.opacity(0.1), lineWidth: 1)
            )
            .padding(.horizontal, 20)
        }
    }
}

private struct ActivityRowView: View {
    let title: String
    let subtitle: String
    let amount: String
    let status: String
    let isLast: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(amount)
                        .font(.headline)
                    Text(status)
                        .font(.subheadline)
                        .foregroundStyle(status == "Paid" ? .green : .orange)
                }
            }
            .padding(16)

            if !isLast {
                Divider()
                    .padding(.leading, 16)
            }
        }
    }
}
