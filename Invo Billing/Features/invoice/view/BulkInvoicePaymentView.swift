import SwiftUI

struct BulkInvoicePaymentView: View {
    let invoices: [InvoiceResponse]
    @ObservedObject var vm: InvoiceViewModel
    let completed: (Set<Int>) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var method: PaymentMethods?
    @State private var date = Date()
    @State private var reference = ""
    @State private var failures: [InvoiceViewModel.BulkPaymentFailure] = []
    @State private var didSubmit = false

    private var total: Double { invoices.reduce(0) { $0 + $1.remaining_amount } }

    var body: some View {
        NavigationStack {
            Form {
                if didSubmit {
                    Section {
                        Label("\(invoices.count - failures.count) of \(invoices.count) payments recorded", systemImage: failures.isEmpty ? "checkmark.circle" : "exclamationmark.triangle")
                        ForEach(failures) { failure in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(failure.invoice.invoice_number).font(.headline)
                                Text(failure.message).font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                        if !failures.isEmpty {
                            Text("Failed invoices remain selected. Refresh and check their payment history before trying again if the server response was interrupted.")
                                .font(.footnote)
                        }
                    }
                } else {
                    Section("Review collection") {
                        LabeledContent("Invoices", value: "\(invoices.count)")
                        LabeledContent("Amount received", value: Money.text(total))
                        Text("Use this for payments received by the same method and date. Record mixed methods and invoices with TDS separately. This batch records cash received only.").font(.footnote).foregroundStyle(.secondary)
                    }
                    Section("Payment details") {
                        Picker("Method", selection: $method) {
                            Text("Choose method").tag(nil as PaymentMethods?)
                            ForEach(PaymentMethods.allCases, id: \.self) { value in
                                Text(value.rawValue.replacingOccurrences(of: "_", with: " ").capitalized).tag(Optional(value))
                            }
                        }
                        DatePicker("Received on", selection: $date, in: ...Date(), displayedComponents: .date)
                        TextField("Reference (optional)", text: $reference)
                    }
                    Section("Invoices receiving payment") {
                        ForEach(invoices) { invoice in
                            LabeledContent(invoice.invoice_number, value: Money.text(invoice.remaining_amount))
                        }
                    }
                    Section {
                        Button {
                            guard let method, !vm.isRecordingBatch else { return }
                            Task {
                                failures = await vm.markPaidBulk(invoices: invoices, method: method, date: date, reference: reference.trimmingCharacters(in: .whitespacesAndNewlines))
                                didSubmit = true
                                completed(Set(failures.map(\.id)))
                            }
                        } label: {
                            if vm.isRecordingBatch { ProgressView("Recording payments…") }
                            else { Text("Record \(Money.text(total)) received") }
                        }
                        .disabled(method == nil || vm.isRecordingBatch)
                    }
                }
            }
            .disabled(vm.isRecordingBatch)
            .navigationTitle("Record payments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(didSubmit ? "Done" : "Cancel") { dismiss() }.disabled(vm.isRecordingBatch)
                }
            }
            .interactiveDismissDisabled(vm.isRecordingBatch)
        }
    }
}
