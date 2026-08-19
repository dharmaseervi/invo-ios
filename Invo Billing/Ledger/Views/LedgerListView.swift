import SwiftUI

struct LedgerListView: View {
    
    @StateObject private var vm: LedgerViewModel
    @Environment(\.dismiss) var dismiss
    
    init(clientID: Int) {
        _vm = StateObject(
            wrappedValue: LedgerViewModel(clientID: clientID)
        )
    }
    
    var body: some View {
        VStack(spacing: 0) {
            
            // Summary
            LedgerSummaryView(
                debit: vm.totalDebit,
                credit: vm.totalCredit,
                balance: vm.closingBalance
            )
            
            Divider()
            
            // Entries
            if vm.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(vm.entries) { entry in
                            LedgerRowView(entry: entry)
                            
                            Divider()
                                .padding(.horizontal, 24)
                        }
                    }
                }
            }
        }
        .onAppear {
            Task { await vm.fetchLedger() }
        }
        .navigationTitle("Ledger Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct LedgerSummaryView: View {
    
    let debit: Double
    let credit: Double
    let balance: Double
    
    var body: some View {
        VStack(spacing: 12) {
            
            summaryRow(
                title: "Total Debit",
                value: debit,
                color: .red
            )
            
            summaryRow(
                title: "Total Credit",
                value: credit,
                color: .green
            )
            
            Divider()
            
            summaryRow(
                title: "Closing Balance",
                value: balance,
                isBold: true,
                color: balance > 0 ? .red : .green
            )
        }
        .padding(24)
    }
    
    private func summaryRow(
        title: String,
        value: Double,
        isBold: Bool = false,
        color: Color = .black
    ) -> some View {
        
        HStack {
            Text(title)
                .font(.system(size: 12))
            
            Spacer()
            
            Text("₹\(value, specifier: "%.2f")")
                .font(.system(
                    size: isBold ? 14 : 12,
                    weight: isBold ? .semibold : .regular
                ))
                .foregroundColor(color)
        }
    }
}


struct LedgerRowView: View {
    
    let entry: LedgerEntryModel
    
    private var titleText: String {
        switch entry.sourceType {
        case .invoice: return "INVOICE"
        case .payment: return "PAYMENT"
        case .creditNote: return "CREDIT NOTE"
        case .opening: return "OPENING"
        }
    }
    
    private var amountText: String {
        if entry.debit > 0 {
            return "+₹\(entry.debit, default: "%.2f")"
        } else {
            return "-₹\(entry.credit, default: "%.2f")"
        }
    }
    
    private var amountColor: Color {
        entry.debit > 0 ? .red : .green
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy"
        return formatter.string(from: entry.createdAt)
    }
    
    var body: some View {
        HStack(spacing: 16) {
            
            // LEFT SIDE
            VStack(alignment: .leading, spacing: 4) {
                
                Text(titleText)
                    .font(.system(size: 13, weight: .semibold))
                
                Text(formattedDate)
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
                
                if let desc = entry.description, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            // RIGHT SIDE
            VStack(alignment: .trailing, spacing: 4) {
                
                Text(amountText)
                    .foregroundColor(amountColor)
                    .font(.system(size: 13, weight: .medium))
                
                Text("Bal ₹\(entry.balance, specifier: "%.2f")")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }
}
