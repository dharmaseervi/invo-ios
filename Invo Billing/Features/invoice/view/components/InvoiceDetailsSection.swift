import SwiftUI

/// Compact "Details" card: invoice number (read-only), invoice date, due date.
struct InvoiceDetailsSection: View {
    var invoiceNumber: String? = nil
    @Binding var invoiceDate: Date
    @Binding var dueDate: Date

    var daysUntilDue: Int {
        Calendar.current.dateComponents([.day], from: invoiceDate, to: dueDate).day ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Details")
                .font(.scaled(13, weight: .medium))
                .foregroundColor(.sMutedFG)

            VStack(spacing: 0) {
                if let invoiceNumber {
                    row(label: "Invoice number") {
                        Text(invoiceNumber)
                            .font(.scaled(14, weight: .medium))
                            .foregroundColor(.sForeground)
                    }
                    divider
                }

                row(label: "Invoice date") {
                    DatePicker("", selection: $invoiceDate, displayedComponents: .date)
                        .labelsHidden()
                        .tint(.sAccent)
                }
                divider

                row(label: "Due date") {
                    DatePicker("", selection: $dueDate, in: invoiceDate..., displayedComponents: .date)
                        .labelsHidden()
                        .tint(.sAccent)
                }

                if daysUntilDue > 0 {
                    divider
                    HStack(spacing: 8) {
                        Image(systemName: "hourglass")
                            .font(.scaled(11))
                        Text("Payment due in \(daysUntilDue) day\(daysUntilDue == 1 ? "" : "s")")
                            .font(.scaled(12))
                        Spacer()
                    }
                    .foregroundColor(.sMutedFG)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                } else if daysUntilDue < 0 {
                    divider
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.scaled(11))
                        Text("Due date is before the invoice date")
                            .font(.scaled(12))
                        Spacer()
                    }
                    .foregroundColor(.sDestructive)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
            }
            .background(Color.sCard)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.sBorder, lineWidth: 0.5))
            .cornerRadius(12)
        }
    }

    private var divider: some View {
        Rectangle().fill(Color.sBorder).frame(height: 0.5).padding(.leading, 14)
    }

    private func row<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label)
                .font(.scaled(14))
                .foregroundColor(.sForeground)
            Spacer()
            content()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
