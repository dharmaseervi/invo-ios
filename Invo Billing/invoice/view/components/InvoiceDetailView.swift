import SwiftUI

struct InvoiceDetailView: View {
    let invoiceID: Int
    @ObservedObject var vm: InvoiceViewModel
    @Environment(\.dismiss) var dismiss
    @State private var showRecordPayment = false
    @State private var showEditInvoice = false
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false

    // Check if invoice is draft
    private var isDraft: Bool {
        vm.invoiceDetail?.status.rawValue == "draft"
    }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {

                // MARK: - Header
                HStack {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Back")
                                .font(
                                    .system(
                                        size: 14,
                                        weight: .light,
                                        design: .default
                                    )
                                )
                        }
                        .foregroundColor(.black)
                    }

                    Spacer()

                    Text("INVOICE DETAILS")
                        .font(
                            .system(
                                size: 12,
                                weight: .semibold,
                                design: .default
                            )
                        )
                        .tracking(0.5)
                        .foregroundColor(.gray)

                    Spacer()

                    Menu {
                        // Edit option - only for drafts
                        if isDraft {
                            Button(action: { showEditInvoice = true }) {
                                Label("Edit Invoice", systemImage: "pencil")
                            }

                            Divider()
                        }

                        Button(action: {
                            vm.selectedInvoiceID = invoiceID
                            vm.showCopyPicker = true
                        }) {
                            Label("Download PDF", systemImage: "arrow.down.doc")
                        }

                        Button(action: {}) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }

                        if let detail = vm.invoiceDetail {
                            NavigationLink {
                                InvoicePrintView(invoiceDetail: detail)
                            } label: {
                                Label("Print", systemImage: "printer")
                            }
                        }

                        // Delete option - only for drafts
                        if isDraft {
                            Divider()

                            Button(
                                role: .destructive,
                                action: { showDeleteConfirmation = true }
                            ) {
                                Label("Delete Invoice", systemImage: "trash")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.black)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)

                Divider()
                    .frame(height: 1)
                    .background(Color.black.opacity(0.08))

                if vm.isFetchingDetail {
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(.black)
                        Text("Loading details...")
                            .font(
                                .system(
                                    size: 13,
                                    weight: .light,
                                    design: .default
                                )
                            )
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let detail = vm.invoiceDetail {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            //action button

                            // MARK: - Action Buttons
                            VStack(spacing: 12) {

                                // EDIT INVOICE (Draft only)
                                if isDraft {
                                    Button {
                                        showEditInvoice = true
                                    } label: {
                                        HStack {
                                            Image(systemName: "pencil")
                                            Text("EDIT INVOICE")
                                                .tracking(0.5)
                                        }
                                        .font(
                                            .system(size: 12, weight: .semibold)
                                        )
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(Color.black)
                                        .foregroundColor(.white)
                                    }
                                }

                                // ISSUE INVOICE (Draft only)
                                if isDraft {
                                    Button {
                                        Task {
                                            await vm.issueInvoice(
                                                invoiceID: detail.id
                                            )
                                        }
                                    } label: {
                                        HStack {
                                            Image(systemName: "paperplane.fill")
                                            Text("ISSUE INVOICE")
                                                .tracking(0.5)
                                        }
                                        .font(
                                            .system(size: 12, weight: .semibold)
                                        )
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .foregroundColor(.black)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 0)
                                                .stroke(
                                                    Color.black,
                                                    lineWidth: 1
                                                )
                                        )
                                    }
                                }
                                // DELETE INVOICE (Draft only)
                                if isDraft {
                                    Button {
                                        showDeleteConfirmation = true
                                    } label: {
                                        HStack {
                                            Image(systemName: "trash")
                                            Text("DELETE")
                                                .tracking(0.5)
                                        }
                                        .font(
                                            .system(size: 12, weight: .semibold)
                                        )
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .foregroundColor(.red)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 0)
                                                .stroke(
                                                    Color.red.opacity(0.3),
                                                    lineWidth: 1
                                                )
                                        )
                                    }
                                }

                                // ISSUE INVOICE (Draft only)
                                if detail.status.rawValue == "draft" {
                                    Button {
                                        Task {
                                            await vm.issueInvoice(
                                                invoiceID: detail.id
                                            )
                                        }
                                    } label: {
                                        HStack {
                                            Image(systemName: "paperplane.fill")
                                            Text("ISSUE INVOICE")
                                                .tracking(0.5)
                                        }
                                        .font(
                                            .system(size: 12, weight: .semibold)
                                        )
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(Color.black)
                                        .foregroundColor(.white)
                                    }
                                }

                                // RECORD PAYMENT (Issued / Partially Paid)
                                if detail.status.rawValue == "issued"
                                    || detail.status.rawValue
                                        == "partially_paid"
                                {
                                    Button {
                                        showRecordPayment = true
                                    } label: {
                                        HStack {
                                            Image(systemName: "creditcard")
                                            Text("RECORD PAYMENT")
                                                .tracking(0.5)
                                        }
                                        .font(
                                            .system(size: 12, weight: .semibold)
                                        )
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(Color.black)
                                        .foregroundColor(.white)
                                    }
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 14)

                            // MARK: - Invoice Header Card
                            VStack(alignment: .leading, spacing: 0) {
                                HStack(spacing: 16) {
                                    // Invoice Number Badge
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(detail.invoice_number)
                                            .font(
                                                .system(
                                                    size: 18,
                                                    weight: .semibold,
                                                    design: .default
                                                )
                                            )
                                            .foregroundColor(.black)

                                        Text(detail.client.name)
                                            .font(
                                                .system(
                                                    size: 13,
                                                    weight: .light,
                                                    design: .default
                                                )
                                            )
                                            .foregroundColor(.gray)
                                    }

                                    Spacer()

                                    // Total Amount
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text(
                                            "₹\(String(format: "%.2f", detail.total))"
                                        )
                                        .font(
                                            .system(
                                                size: 18,
                                                weight: .semibold,
                                                design: .default
                                            )
                                        )
                                        .foregroundColor(.black)

                                        Text("Total Amount")
                                            .font(
                                                .system(
                                                    size: 10,
                                                    weight: .light,
                                                    design: .default
                                                )
                                            )
                                            .foregroundColor(.gray)
                                            .tracking(0.2)
                                    }
                                }
                                .padding(.horizontal, 24)
                                .padding(.vertical, 20)
                                .background(Color.black.opacity(0.02))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 0)
                                        .stroke(
                                            Color.black.opacity(0.08),
                                            lineWidth: 1
                                        )
                                )
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 24)
                            .padding(.bottom, 32)

                            // MARK: - Dates Section
                            VStack(alignment: .leading, spacing: 0) {
                                Text("DATES")
                                    .font(
                                        .system(
                                            size: 11,
                                            weight: .semibold,
                                            design: .default
                                        )
                                    )
                                    .tracking(1)
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 24)
                                    .padding(.bottom, 16)

                                HStack(spacing: 0) {
                                    DateInfoCardZara(
                                        label: "Issue Date",
                                        value: detail.invoice_date
                                    )

                                    Divider()
                                        .frame(width: 1)
                                        .background(Color.black.opacity(0.08))

                                    DateInfoCardZara(
                                        label: "Due Date",
                                        value: detail.due_date
                                    )
                                }
                                .padding(.horizontal, 24)
                                .padding(.bottom, 32)
                            }

                            // MARK: - Line Items Section
                            VStack(alignment: .leading, spacing: 0) {
                                Text("LINE ITEMS")
                                    .font(
                                        .system(
                                            size: 11,
                                            weight: .semibold,
                                            design: .default
                                        )
                                    )
                                    .tracking(1)
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 24)
                                    .padding(.bottom, 16)

                                VStack(spacing: 0) {
                                    ForEach(
                                        Array(detail.items.enumerated()),
                                        id: \.element.id
                                    ) { index, item in
                                        ItemRowCardZara(item: item)

                                        if index < detail.items.count - 1 {
                                            Divider()
                                                .frame(height: 1)
                                                .background(
                                                    Color.black.opacity(0.08)
                                                )
                                                .padding(.horizontal, 24)
                                        }
                                    }
                                }
                                .padding(.horizontal, 24)
                                .padding(.bottom, 32)
                            }

                            // MARK: - Summary Section
                            VStack(alignment: .leading, spacing: 0) {
                                Text("SUMMARY")
                                    .font(
                                        .system(
                                            size: 11,
                                            weight: .semibold,
                                            design: .default
                                        )
                                    )
                                    .tracking(1)
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 24)
                                    .padding(.bottom, 16)

                                VStack(spacing: 0) {
                                    SummaryRowItemZara(
                                        label: "Subtotal",
                                        value: detail.subtotal,
                                        isTotal: false
                                    )

                                    Divider()
                                        .frame(height: 1)
                                        .background(Color.black.opacity(0.08))
                                        .padding(.horizontal, 24)

                                    SummaryRowItemZara(
                                        label: "Tax",
                                        value: detail.tax,
                                        isTotal: false
                                    )

                                    Divider()
                                        .frame(height: 1)
                                        .background(Color.black.opacity(0.08))
                                        .padding(.horizontal, 24)

                                    SummaryRowItemZara(
                                        label: "Total",
                                        value: detail.total,
                                        isTotal: true
                                    )
                                }
                                .padding(.horizontal, 24)
                                .padding(.bottom, 48)
                            }
                        }
                    }
                } else if let error = vm.errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 32, weight: .thin))
                            .foregroundColor(.red)

                        Text("Error Loading Invoice")
                            .font(
                                .system(
                                    size: 14,
                                    weight: .semibold,
                                    design: .default
                                )
                            )

                        Text(error)
                            .font(
                                .system(
                                    size: 12,
                                    weight: .light,
                                    design: .default
                                )
                            )
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(24)
                }
            }

            // Loading Overlay
            if vm.isFetchingDetail {
                ZStack {
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()

                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.3)
                            .tint(.black)

                        Text("Loading details...")
                            .font(
                                .system(
                                    size: 13,
                                    weight: .light,
                                    design: .default
                                )
                            )
                            .foregroundColor(.black)
                    }
                    .padding(32)
                    .background(Color.white)
                    .cornerRadius(8)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            Task {
                await vm.fetchInvoiceDetail(invoiceID: invoiceID)
            }
        }
        .navigationDestination(isPresented: $showRecordPayment) {
            if let detail = vm.invoiceDetail {
                RecordPaymentView(
                    vm: RecordPaymentViewModel(
                        companyID: SessionManager.shared.selectedCompanyId ?? 0,
                        clientID: detail.client.id,
                        context: .invoice(
                            invoiceID: detail.id,
                            remaining: detail.remaining_amount
                        )
                    )
                )
            }
        }
        .confirmationDialog(
            "Select Copy",
            isPresented: $vm.showCopyPicker,
            titleVisibility: .visible
        ) {
            Button("Original") {
                Task {
                    if let id = vm.selectedInvoiceID {
                        await vm.generateInvoicePDFFromServer(
                            invoiceID: id,
                            copy: "original"
                        )
                    }
                }
            }
            Button("Duplicate") {
                Task {
                    if let id = vm.selectedInvoiceID {
                        await vm.generateInvoicePDFFromServer(
                            invoiceID: id,
                            copy: "duplicate"
                        )
                    }
                }
            }
            Button("Buyer Copy") {
                Task {
                    if let id = vm.selectedInvoiceID {
                        await vm.generateInvoicePDFFromServer(
                            invoiceID: id,
                            copy: "buyer"
                        )
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("ERROR", isPresented: $vm.showAlert, presenting: vm.errorMessage)
        { _ in
            Button("OK") { vm.showAlert = false }
        } message: { errorMessage in
            Text(errorMessage)
        }
        // Edit Invoice Sheet
        .sheet(isPresented: $showEditInvoice) {
            EditInvoiceView(invoiceID: invoiceID)
        }
        .onChange(of: showEditInvoice) { isPresented in
            if !isPresented {
                // Refresh invoice detail after editing
                Task { await vm.fetchInvoiceDetail(invoiceID: invoiceID) }
            }
        }
    }
}

// MARK: - Date Info Card (Zara Style)
struct DateInfoCardZara: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 10, weight: .regular, design: .default))
                .foregroundColor(.gray)
                .tracking(0.3)

            Text(value)
                .font(.system(size: 13, weight: .light, design: .default))
                .foregroundColor(.black)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

// MARK: - Item Row Card (Zara Style)
struct ItemRowCardZara: View {
    let item: InvoiceItemDetail

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Item #\(item.item_id)")
                        .font(.system(size: 13, weight: .semibold))

                    Text("Qty: \(item.qty)")
                        .font(.system(size: 11, weight: .light))
                        .foregroundColor(.gray)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    Text("₹\(String(format: "%.2f", item.total))")
                        .font(.system(size: 13, weight: .semibold))

                    Text("₹\(String(format: "%.2f", item.rate)) each")
                        .font(.system(size: 11, weight: .light))
                        .foregroundColor(.gray)
                }
            }
            .padding(.vertical, 12)

            VStack(spacing: 6) {
                if item.discount > 0 {
                    summaryRow(label: "Discount", value: -item.discount)
                }

                if item.tax_rate > 0 {
                    let taxAmount =
                        (item.total / (1 + item.tax_rate / 100))
                        * (item.tax_rate / 100)
                    summaryRow(
                        label: "Tax (\(item.tax_rate)%)",
                        value: taxAmount
                    )
                }
            }
            .padding(.vertical, 6)
        }
    }

    private func summaryRow(label: String, value: Double) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11, weight: .light))
                .foregroundColor(.gray)
            Spacer()
            Text("₹\(String(format: "%.2f", value))")
                .font(.system(size: 11, weight: .light))
        }
    }
}

// MARK: - Summary Row Item (Zara Style)
struct SummaryRowItemZara: View {
    let label: String
    let value: Double
    let isTotal: Bool

    var body: some View {
        HStack(spacing: 0) {
            Text(label)
                .font(
                    .system(
                        size: isTotal ? 13 : 12,
                        weight: isTotal ? .semibold : .light,
                        design: .default
                    )
                )
                .foregroundColor(.black)

            Spacer()

            Text("₹\(String(format: "%.2f", value))")
                .font(
                    .system(
                        size: isTotal ? 14 : 12,
                        weight: isTotal ? .semibold : .light,
                        design: .default
                    )
                )
                .foregroundColor(.black)
        }
        .padding(.horizontal, 0)
        .padding(.vertical, 12)
    }
}
