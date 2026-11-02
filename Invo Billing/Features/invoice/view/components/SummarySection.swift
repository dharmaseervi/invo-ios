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
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.sMutedFG)
                .padding(.horizontal, AppSpacing.page)
                .padding(.bottom, 10)

            VStack(spacing: 0) {
                SummaryRowZara(label: "Subtotal", value: subtotal, isTotal: false)

                Rectangle().fill(Color.sBorder).frame(height: 0.5).padding(.horizontal, 14)

                AdaptiveFormRow {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tax")
                            .font(.subheadline)
                            .foregroundStyle(Color.sForeground)
                        Text("(\(String(format: "%.1f", taxPercentage))%)")
                            .font(.caption)
                            .foregroundStyle(Color.sMutedFG)
                    }

                    Spacer()

                    Text(Money.text(tax)).moneyLine()
                        .font(.subheadline)
                        .foregroundStyle(Color.sForeground)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

                Rectangle().fill(Color.sBorder).frame(height: 0.5).padding(.horizontal, 14)

                AdaptiveFormRow {
                    Text("Discount")
                        .font(.subheadline)
                        .foregroundStyle(Color.sForeground)

                    Spacer()

                    HStack(spacing: 2) {
                        Text("₹")
                            .font(.subheadline)
                            .foregroundStyle(Color.sMutedFG)
                        TextField("0.00", text: $discountText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(.subheadline)
                            .foregroundStyle(Color.sForeground)
                            .tint(Color.sAccent)
                            .frame(minWidth: 80, idealWidth: 120)
                            .accessibilityLabel("Invoice discount")
                            .focused($discountFocused)
                            .onChange(of: discountText) { _, newValue in
                                discount = min(max(Double(newValue) ?? 0, 0), subtotal + tax)
                            }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .onAppear {
                    discountText = discount > 0 ? Money.editable(discount) : ""
                }
                .onChange(of: discountFocused) { _, focused in
                    if !focused {
                        discountText = discount > 0 ? Money.editable(discount) : ""
                    }
                }

                Rectangle().fill(Color.sBorder).frame(height: 0.5).padding(.horizontal, 14)

                // TDS row
                AdaptiveFormRow {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TDS deduction")
                            .font(.subheadline)
                            .foregroundStyle(Color.sForeground)
                        Text("Buyer deducts from payment")
                            .font(.caption)
                            .foregroundStyle(Color.sMutedFG)
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
                                .font(.subheadline)
                                .foregroundStyle(tdsRate > 0 ? Color.sAccent : Color.sMutedFG)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundStyle(Color.sMutedFG)
                        }
                        .frame(minHeight: 44)
                        .accessibilityLabel("TDS rate")
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.sMuted)
                        .clipShape(.rect(cornerRadius: 6))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

                if tdsRate > 0 {
                    Rectangle().fill(Color.sBorder).frame(height: 0.5).padding(.horizontal, 14)
                    AdaptiveFormRow {
                        Text("TDS @ \(tdsRate.formatted(.number.precision(.fractionLength(0...1))))%")
                            .font(.subheadline)
                            .foregroundStyle(Color.sMutedFG)
                        Spacer()
                        Text("- \(Money.text(tdsAmount))").moneyLine()
                            .font(.subheadline)
                            .foregroundStyle(Color.sDestructive)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }

                Rectangle().fill(Color.sBorder).frame(height: 0.5).padding(.horizontal, 14)

                AdaptiveFormRow {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(tdsRate > 0 ? "Expected cash receivable" : "Invoice total")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.sForeground)
                        Text(tdsRate > 0 ? "If the buyer withholds the expected TDS" : "Payable by the due date")
                            .font(.caption)
                            .foregroundStyle(Color.sMutedFG)
                    }

                    Spacer()

                    Text(Money.text(tdsRate > 0 ? netReceivable : total)).moneyLine()
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.sForeground)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
            }
            .background(Color.sCard)
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.sBorder, lineWidth: 0.5)
            }
            .clipShape(.rect(cornerRadius: 10))
            .padding(.horizontal, AppSpacing.page)
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
        AdaptiveFormRow {
            Text(label)
                .font(isTotal ? .headline : .subheadline)
                .foregroundStyle(Color.sForeground)

            Spacer()

            Text(Money.text(value)).moneyLine()
                .font(isTotal ? .headline : .subheadline)
                .foregroundStyle(Color.sForeground)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}
