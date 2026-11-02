import SwiftUI

/// Compact "Details" card: invoice number (read-only), invoice date, due date, doc type.
struct InvoiceDetailsSection: View {
    var invoiceNumber: String? = nil
    @Binding var invoiceDate: Date
    @Binding var dueDate: Date
    var docType: Binding<String>? = nil

    var daysUntilDue: Int {
        Calendar.current.dateComponents([.day], from: invoiceDate, to: dueDate).day ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Details")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.sMutedFG)

            VStack(spacing: 0) {
                if let invoiceNumber {
                    row(label: "Invoice number") {
                        Text(invoiceNumber)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.sForeground)
                    }
                    divider
                }

                if let docType {
                    row(label: "Invoice type") {
                        Picker("Invoice type", selection: docType) {
                            Text("Tax Invoice").tag("")
                            Text("Credit Invoice").tag("CREDIT INVOICE")
                        }
                        .pickerStyle(.menu)
                        .tint(Color.sAccent)
                    }
                    divider
                }

                row(label: "Invoice date") {
                    DatePicker("Invoice date", selection: $invoiceDate, displayedComponents: .date)
                        .labelsHidden()
                        .tint(Color.sAccent)
                }
                divider

                row(label: "Due date") {
                    DatePicker("Due date", selection: $dueDate, in: invoiceDate..., displayedComponents: .date)
                        .labelsHidden()
                        .tint(Color.sAccent)
                }

                if daysUntilDue > 0 {
                    divider
                    HStack(spacing: 8) {
                        Image(systemName: "hourglass")
                            .font(.caption)
                        Text("Payment due in \(daysUntilDue) day\(daysUntilDue == 1 ? "" : "s")")
                            .font(.footnote)
                        Spacer()
                    }
                    .foregroundStyle(Color.sMutedFG)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                } else if daysUntilDue < 0 {
                    divider
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.caption)
                        Text("Due date is before the invoice date")
                            .font(.footnote)
                        Spacer()
                    }
                    .foregroundStyle(Color.sDestructive)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
            }
            .background(Color.sCard)
            .overlay { RoundedRectangle(cornerRadius: 12).stroke(Color.sBorder, lineWidth: 0.5) }
            .clipShape(.rect(cornerRadius: 12))
        }
    }

    private var divider: some View {
        Rectangle().fill(Color.sBorder).frame(height: 0.5).padding(.leading, 14)
    }

    private func row<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        AdaptiveFormRow {
            Text(label)
                .font(.body)
                .foregroundStyle(Color.sForeground)
            Spacer()
            content()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
