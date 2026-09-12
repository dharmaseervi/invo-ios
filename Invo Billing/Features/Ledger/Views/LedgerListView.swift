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
        ZStack {
            Color.sBackground.ignoresSafeArea()

            VStack(spacing: 0) {

                // Summary
                LedgerSummaryView(
                    debit: vm.totalDebit,
                    credit: vm.totalCredit,
                    balance: vm.closingBalance
                )

                Rectangle().fill(Color.sBorder).frame(height: 0.5)

                // Entries
                if vm.isLoading {
                    Spacer()
                    ProgressView().tint(.sAccent)
                    Spacer()
                } else if vm.entries.isEmpty {
                    Spacer()
                    VStack(spacing: 10) {
                        Image(systemName: "book")
                            .font(.scaled(22))
                            .foregroundColor(.sMutedFG)
                        Text("No transactions yet")
                            .font(.scaled(14, weight: .medium))
                            .foregroundColor(.sForeground)
                        Text("Invoices, payments, and credit notes for this client will appear here")
                            .font(.scaled(12))
                            .foregroundColor(.sMutedFG)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(vm.entries) { entry in
                                LedgerRowView(entry: entry)
                            }
                        }
                        .padding(20)
                    }
                }
            }
        }
        .onAppear {
            Task { await vm.fetchLedger() }
        }
        .navigationTitle("Ledger details")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: $vm.showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.errorMessage ?? "Something went wrong")
        }
    }
}

struct LedgerSummaryView: View {

    let debit: Double
    let credit: Double
    let balance: Double

    var body: some View {
        VStack(spacing: 10) {

            summaryRow(title: "Total debit", value: debit, color: .sDestructive)
            summaryRow(title: "Total credit", value: credit, color: Color(red: 0.086, green: 0.639, blue: 0.341))

            Rectangle().fill(Color.sBorder).frame(height: 0.5)

            summaryRow(
                title: "Closing balance",
                value: balance,
                isBold: true,
                color: balance > 0 ? .sDestructive : Color(red: 0.086, green: 0.639, blue: 0.341)
            )
        }
        .padding(20)
        .background(Color.sCard)
    }

    private func summaryRow(
        title: String,
        value: Double,
        isBold: Bool = false,
        color: Color = .primary
    ) -> some View {

        HStack {
            Text(title)
                .font(.scaled(13))
                .foregroundColor(.sMutedFG)

            Spacer()

            Text(Money.text(value))
                .font(.system(
                    size: isBold ? 15 : 13,
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
        case .invoice: return "Invoice"
        case .payment: return "Payment"
        case .creditNote: return "Credit Note"
        case .opening: return "Opening"
        }
    }

    private var amountText: String {
        if entry.debit > 0 {
            return "+\(Money.text(entry.debit))"
        } else {
            return Money.text(-entry.credit)
        }
    }

    private var amountColor: Color {
        entry.debit > 0 ? .sDestructive : Color(red: 0.086, green: 0.639, blue: 0.341)
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
                    .font(.scaled(13, weight: .semibold))
                    .foregroundColor(.sForeground)

                Text(formattedDate)
                    .font(.scaled(11))
                    .foregroundColor(.sMutedFG)

                if let desc = entry.description, !desc.isEmpty {
                    Text(desc)
                        .font(.scaled(11))
                        .foregroundColor(.sMutedFG)
                }
            }

            Spacer()

            // RIGHT SIDE
            VStack(alignment: .trailing, spacing: 4) {

                Text(amountText)
                    .foregroundColor(amountColor)
                    .font(.scaled(13, weight: .medium))

                Text("Bal \(Money.text(entry.balance))")
                    .font(.scaled(11))
                    .foregroundColor(.sMutedFG)
            }
        }
        .padding(14)
        .background(Color.sCard)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.sBorder, lineWidth: 0.5))
        .cornerRadius(12)
    }
}
