import SwiftUI

struct SummarySection: View {
    let subtotal: Double
    let tax: Double
    @Binding var discount: Double
    let total: Double

    @State private var discountText: String = ""
    @FocusState private var discountFocused: Bool

    var taxPercentage: Double {
        subtotal > 0 ? (tax / subtotal) * 100 : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Summary")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.sMutedFG)
                .padding(.horizontal, 20)
                .padding(.bottom, 10)

            VStack(spacing: 0) {
                SummaryRowZara(label: "Subtotal", value: subtotal, isTotal: false)

                Rectangle().fill(Color.sBorder).frame(height: 0.5).padding(.horizontal, 14)

                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tax")
                            .font(.system(size: 13))
                            .foregroundColor(.sForeground)
                        Text("(\(String(format: "%.1f", taxPercentage))%)")
                            .font(.system(size: 11))
                            .foregroundColor(.sMutedFG)
                    }

                    Spacer()

                    Text(Money.text(tax))
                        .font(.system(size: 13))
                        .foregroundColor(.sForeground)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

                Rectangle().fill(Color.sBorder).frame(height: 0.5).padding(.horizontal, 14)

                HStack(spacing: 0) {
                    Text("Discount")
                        .font(.system(size: 13))
                        .foregroundColor(.sForeground)

                    Spacer()

                    HStack(spacing: 2) {
                        Text("₹")
                            .font(.system(size: 13))
                            .foregroundColor(.sMutedFG)
                        TextField("0.00", text: $discountText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(.system(size: 13))
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

                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Total amount")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.sForeground)
                        Text("Amount due by invoice date")
                            .font(.system(size: 11))
                            .foregroundColor(.sMutedFG)
                    }

                    Spacer()

                    Text(Money.text(total))
                        .font(.system(size: 16, weight: .semibold))
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
                .font(.system(size: isTotal ? 14 : 13, weight: isTotal ? .semibold : .regular))
                .foregroundColor(.sForeground)

            Spacer()

            Text(Money.text(value))
                .font(.system(size: isTotal ? 15 : 13, weight: isTotal ? .semibold : .regular))
                .foregroundColor(.sForeground)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}
