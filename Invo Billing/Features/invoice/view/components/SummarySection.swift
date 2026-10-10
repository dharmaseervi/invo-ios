import SwiftUI

struct SummarySection: View {
    let subtotal: Double
    let tax: Double
    @Binding var discount: Double
    let total: Double
    @Binding var tdsRate: Double

    @State private var discountText: String = ""
    @FocusState private var discountFocused: Bool

    private static let tdsOptions: [Double] = [0, 1, 2, 2.5, 5, 10]

    var taxPercentage: Double {
        subtotal > 0 ? (tax / subtotal) * 100 : 0
    }

    private var tdsAmount: Double { total * tdsRate / 100 }
    private var netReceivable: Double { total - tdsAmount }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Summary")
                .font(.scaled(13, weight: .medium))
                .foregroundColor(.sMutedFG)
                .padding(.horizontal, 20)
                .padding(.bottom, 10)

            VStack(spacing: 0) {
                SummaryRowZara(label: "Subtotal", value: subtotal, isTotal: false)

                Rectangle().fill(Color.sBorder).frame(height: 0.5).padding(.horizontal, 14)

                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tax")
                            .font(.scaled(13))
                            .foregroundColor(.sForeground)
                        Text("(\(String(format: "%.1f", taxPercentage))%)")
                            .font(.scaled(11))
                            .foregroundColor(.sMutedFG)
                    }

                    Spacer()

                    Text(Money.text(tax)).moneyLine()
                        .font(.scaled(13))
                        .foregroundColor(.sForeground)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

                Rectangle().fill(Color.sBorder).frame(height: 0.5).padding(.horizontal, 14)

                HStack(spacing: 0) {
                    Text("Discount")
                        .font(.scaled(13))
                        .foregroundColor(.sForeground)

                    Spacer()

                    HStack(spacing: 2) {
                        Text("₹")
                            .font(.scaled(13))
                            .foregroundColor(.sMutedFG)
                        TextField("0.00", text: $discountText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(.scaled(13))
                            .foregroundColor(.sForeground)
                            .tint(.sAccent)
                            .frame(width: 80)
                            .focused($discountFocused)
                            .onChange(of: discountText) { newValue in
                                discount = min(max(Double(newValue) ?? 0, 0), subtotal + tax)
                            }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .onAppear {
                    discountText = discount > 0 ? Money.editable(discount) : ""
                }
                .onChange(of: discountFocused) { focused in
                    if !focused {
                        discountText = discount > 0 ? Money.editable(discount) : ""
                    }
                }

                Rectangle().fill(Color.sBorder).frame(height: 0.5).padding(.horizontal, 14)

                // TDS row
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TDS deduction")
                            .font(.scaled(13))
                            .foregroundColor(.sForeground)
                        Text("Buyer deducts from payment")
                            .font(.scaled(11))
                            .foregroundColor(.sMutedFG)
                    }
                    Spacer()
                    Menu {
                        ForEach(Self.tdsOptions, id: \.self) { rate in
                            Button(rate == 0 ? "None" : "\(rate.formatted(.number.precision(.fractionLength(0...1))))%") {
                                tdsRate = rate
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(tdsRate == 0 ? "None" : "\(tdsRate.formatted(.number.precision(.fractionLength(0...1))))%")
                                .font(.scaled(13))
                                .foregroundColor(tdsRate > 0 ? .sAccent : .sMutedFG)
                            Image(systemName: "chevron.down")
                                .font(.scaled(10))
                                .foregroundColor(.sMutedFG)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.sMuted)
                        .cornerRadius(6)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

                if tdsRate > 0 {
                    Rectangle().fill(Color.sBorder).frame(height: 0.5).padding(.horizontal, 14)
                    HStack {
                        Text("TDS @ \(tdsRate.formatted(.number.precision(.fractionLength(0...1))))%")
                            .font(.scaled(13))
                            .foregroundColor(.sMutedFG)
                        Spacer()
                        Text("- \(Money.text(tdsAmount))").moneyLine()
                            .font(.scaled(13))
                            .foregroundColor(Color(red: 0.863, green: 0.149, blue: 0.149))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }

                Rectangle().fill(Color.sBorder).frame(height: 0.5).padding(.horizontal, 14)

                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(tdsRate > 0 ? "Net receivable" : "Total amount")
                            .font(.scaled(14, weight: .semibold))
                            .foregroundColor(.sForeground)
                        Text(tdsRate > 0 ? "After TDS deduction" : "Payable by the due date")
                            .font(.scaled(11))
                            .foregroundColor(.sMutedFG)
                    }

                    Spacer()

                    Text(Money.text(tdsRate > 0 ? netReceivable : total)).moneyLine()
                        .font(.scaled(16, weight: .semibold))
                        .foregroundColor(.sForeground)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
            }
            .background(Color.sCard)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.sBorder, lineWidth: 0.5)
            )
            .cornerRadius(10)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
}

// MARK: - Summary Row Component
struct SummaryRowZara: View {
    let label: String
    let value: Double
    var isTotal: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            Text(label)
                .font(.scaled(isTotal ? 14 : 13, weight: isTotal ? .semibold : .regular))
                .foregroundColor(.sForeground)

            Spacer()

            Text(Money.text(value)).moneyLine()
                .font(.scaled(isTotal ? 15 : 13, weight: isTotal ? .semibold : .regular))
                .foregroundColor(.sForeground)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}
