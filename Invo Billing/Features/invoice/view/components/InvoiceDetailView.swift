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

    private func statusConfig(for detail: InvoiceDetailResponse) -> (label: String, color: Color) {
        if detail.is_overdue { return ("Overdue", Color(red: 0.863, green: 0.149, blue: 0.149)) }
        switch detail.status {
        case .paid:      return ("Paid",      Color(red: 0.086, green: 0.639, blue: 0.341))
        case .pending:   return ("Pending",   Color(red: 0.722, green: 0.494, blue: 0.051))
        case .partial:   return ("Partial",   Color(red: 0.722, green: 0.494, blue: 0.051))
        case .draft:     return ("Draft",     Color(UIColor.systemGray))
        case .issued:    return ("Issued",    Color.sAccent)
        case .cancelled: return ("Cancelled", Color(UIColor.systemGray))
        case .sent:      return ("Sent",      Color(UIColor.systemGray))
        case .overdue:   return ("Overdue",   Color(red: 0.863, green: 0.149, blue: 0.149))
        }
    }

    private func initials(for name: String) -> String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    var body: some View {
        ZStack {
            Color.sBackground.ignoresSafeArea()

            VStack(spacing: 0) {

                Color.clear.frame(height: 0)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                    Menu {
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

                        if let detail = vm.invoiceDetail {
                            NavigationLink {
                                InvoicePrintView(invoiceDetail: detail)
                            } label: {
                                Label("Print", systemImage: "printer")
                            }

                            Button(action: {
                                vm.selectedEmailInvoiceID = invoiceID
                                vm.emailIsReminder = false
                                vm.showEmailSheet = true
                            }) {
                                Label("Email invoice", systemImage: "envelope")
                            }

                            if detail.remaining_amount > 0 && detail.status != .draft && detail.status != .cancelled {
                                Button(action: {
                                    vm.selectedEmailInvoiceID = invoiceID
                                    vm.emailIsReminder = true
                                    vm.showEmailSheet = true
                                }) {
                                    Label("Send payment reminder", systemImage: "bell")
                                }
                            }
                        }

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
                    }
                    }
                }

                if vm.isFetchingDetail {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(.sAccent)
                        Text("Loading details...")
                            .font(.system(size: 13))
                            .foregroundColor(.sMutedFG)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let detail = vm.invoiceDetail {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {

                            // MARK: - Invoice Header Card
                            VStack(alignment: .leading, spacing: 16) {
                                HStack(spacing: 14) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.sAccentMuted)
                                            .frame(width: 48, height: 48)
                                        Text(initials(for: detail.client.name))
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(.sAccent)
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(detail.client.name)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.sForeground)
                                        Text(detail.invoice_number)
                                            .font(.system(size: 13))
                                            .foregroundColor(.sMutedFG)
                                    }

                                    Spacer()

                                    let config = statusConfig(for: detail)
                                    Text(config.label)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(config.color)
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 4)
                                        .background(Capsule().fill(config.color.opacity(0.1)))
                                }

                                Rectangle().fill(Color.sBorder).frame(height: 0.5)

                                HStack(alignment: .firstTextBaseline) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("Total amount")
                                            .font(.system(size: 11))
                                            .foregroundColor(.sMutedFG)
                                        Text(Money.text(detail.total))
                                            .font(.system(size: 22, weight: .bold))
                                            .foregroundColor(.sForeground)
                                    }
                                    Spacer()
                                    if detail.paid_amount > 0 && detail.status != .paid {
                                        VStack(alignment: .trailing, spacing: 3) {
                                            Text("Remaining")
                                                .font(.system(size: 11))
                                                .foregroundColor(.sMutedFG)
                                            Text(Money.text(detail.remaining_amount))
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundColor(Color(red: 0.722, green: 0.494, blue: 0.051))
                                        }
                                    }
                                }

                                if detail.paid_amount > 0 && detail.status != .paid {
                                    GeometryReader { geo in
                                        let progress = detail.total > 0 ? min(detail.paid_amount / detail.total, 1) : 0
                                        ZStack(alignment: .leading) {
                                            Capsule().fill(Color.sMuted).frame(height: 6)
                                            Capsule().fill(Color.sAccent)
                                                .frame(width: geo.size.width * progress, height: 6)
                                        }
                                    }
                                    .frame(height: 6)
                                    Text("\(Money.text(detail.paid_amount)) paid so far")
                                        .font(.system(size: 11))
                                        .foregroundColor(.sMutedFG)
                                }
                            }
                            .padding(18)
                            .background(Color.sCard)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.sBorder, lineWidth: 0.5))
                            .cornerRadius(14)
                            .padding(.horizontal, 20)
                            .padding(.top, 16)

                            // MARK: - Action Buttons
                            VStack(spacing: 10) {

                                if isDraft {
                                    Button {
                                        showEditInvoice = true
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: "pencil")
                                            Text("Edit invoice")
                                        }
                                        .font(.system(size: 14, weight: .semibold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(Color.sPrimary)
                                        .foregroundColor(.sAccentFG)
                                        .cornerRadius(10)
                                    }

                                    Button {
                                        Task {
                                            await vm.issueInvoice(invoiceID: detail.id)
                                        }
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: "paperplane.fill")
                                            Text("Issue invoice")
                                        }
                                        .font(.system(size: 14, weight: .semibold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .foregroundColor(.sForeground)
                                        .background(Color.sCard)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(Color.sBorder, lineWidth: 0.5)
                                        )
                                        .cornerRadius(10)
                                    }

                                    Button {
                                        showDeleteConfirmation = true
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: "trash")
                                            Text("Delete")
                                        }
                                        .font(.system(size: 14, weight: .semibold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .foregroundColor(.sDestructive)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(Color.sDestructive.opacity(0.3), lineWidth: 0.5)
                                        )
                                        .cornerRadius(10)
                                    }
                                }

                                // RECORD PAYMENT (Issued / Partially Paid)
                                if detail.status == .issued || detail.status == .partial {
                                    Button {
                                        showRecordPayment = true
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: "creditcard")
                                            Text("Record payment")
                                        }
                                        .font(.system(size: 14, weight: .semibold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(Color.sPrimary)
                                        .foregroundColor(.sAccentFG)
                                        .cornerRadius(10)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 16)

                            // MARK: - Dates Section
                            VStack(alignment: .leading, spacing: 0) {
                                Text("Dates")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.sMutedFG)
                                    .padding(.horizontal, 20)
                                    .padding(.bottom, 10)

                                HStack(spacing: 0) {
                                    DateInfoCardZara(label: "Issue date", value: detail.invoice_date)
                                    Rectangle().fill(Color.sBorder).frame(width: 0.5)
                                    DateInfoCardZara(label: "Due date", value: detail.due_date)
                                }
                                .background(Color.sCard)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.sBorder, lineWidth: 0.5))
                                .cornerRadius(10)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 20)
                            }

                            // MARK: - Line Items Section
                            VStack(alignment: .leading, spacing: 0) {
                                Text("Line items")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.sMutedFG)
                                    .padding(.horizontal, 20)
                                    .padding(.bottom, 10)

                                VStack(spacing: 10) {
                                    ForEach(Array(detail.items.enumerated()), id: \.element.id) { index, item in
                                        ItemRowCardZara(
                                            item: item,
                                            itemName: vm.itemNames[item.item_id]
                                        )
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.bottom, 20)
                            }

                            // MARK: - Summary Section
                            VStack(alignment: .leading, spacing: 0) {
                                Text("Summary")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.sMutedFG)
                                    .padding(.horizontal, 20)
                                    .padding(.bottom, 10)

                                VStack(spacing: 0) {
                                    SummaryRowItemZara(label: "Subtotal", value: detail.subtotal, isTotal: false)

                                    Rectangle().fill(Color.sBorder).frame(height: 0.5).padding(.horizontal, 14)

                                    SummaryRowItemZara(label: "Tax", value: detail.tax, isTotal: false)

                                    if detail.discount > 0 {
                                        Rectangle().fill(Color.sBorder).frame(height: 0.5).padding(.horizontal, 14)
                                        SummaryRowItemZara(label: "Discount", value: -detail.discount, isTotal: false)
                                    }

                                    Rectangle().fill(Color.sBorder).frame(height: 0.5).padding(.horizontal, 14)

                                    SummaryRowItemZara(label: "Total", value: detail.total, isTotal: true)
                                }
                                .background(Color.sCard)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.sBorder, lineWidth: 0.5))
                                .cornerRadius(10)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 40)
                            }
                        }
                    }
                } else if let error = vm.errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 28))
                            .foregroundColor(.sDestructive)

                        Text("Error loading invoice")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.sForeground)

                        Text(error)
                            .font(.system(size: 12))
                            .foregroundColor(.sMutedFG)
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

                    VStack(spacing: 14) {
                        ProgressView()
                            .scaleEffect(1.3)
                            .tint(.sAccent)

                        Text("Loading details...")
                            .font(.system(size: 13))
                            .foregroundColor(.sForeground)
                    }
                    .padding(32)
                    .background(Color.sCard)
                    .cornerRadius(12)
                }
            }
        }
        .navigationTitle("Invoice details")
        .navigationBarTitleDisplayMode(.inline)
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
                        clientName: detail.client.name,
                        invoiceNumber: detail.invoice_number,
                        context: .invoice(
                            invoiceID: detail.id,
                            remaining: detail.remaining_amount
                        )
                    )
                )
            }
        }
        .confirmationDialog(
            "Delete this invoice?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete invoice", role: .destructive) {
                Task {
                    isDeleting = true
                    let deleted = await vm.deleteInvoice(invoiceID: invoiceID)
                    isDeleting = false
                    if deleted { dismiss() }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This draft will be removed permanently. Issued invoices cannot be deleted — reverse those with a credit note.")
        }
        .confirmationDialog(
            "Select Copy",
            isPresented: $vm.showCopyPicker,
            titleVisibility: .visible
        ) {
            Button("Original") {
                Task {
                    if let id = vm.selectedInvoiceID {
                        await vm.generateInvoicePDFFromServer(invoiceID: id, copy: "original")
                    }
                }
            }
            Button("Duplicate") {
                Task {
                    if let id = vm.selectedInvoiceID {
                        await vm.generateInvoicePDFFromServer(invoiceID: id, copy: "duplicate")
                    }
                }
            }
            Button("Buyer Copy") {
                Task {
                    if let id = vm.selectedInvoiceID {
                        await vm.generateInvoicePDFFromServer(invoiceID: id, copy: "buyer")
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .presentationCompactAdaptation(.sheet)
        .alert("Error", isPresented: $vm.showAlert, presenting: vm.errorMessage) { _ in
            Button("OK") { vm.showAlert = false }
        } message: { errorMessage in
            Text(errorMessage)
        }
        .confirmationDialog(
            "Not enough stock",
            isPresented: $vm.showOversellConfirm,
            titleVisibility: .visible
        ) {
            Button("Issue anyway", role: .destructive) {
                Task { await vm.confirmIssueDespiteOversell() }
            }
            Button("Cancel", role: .cancel) {
                vm.pendingIssueInvoiceID = nil
                vm.oversellItems = []
            }
        } message: {
            Text(vm.oversellItems.map {
                "\($0.name): \($0.available) in stock, \($0.requested) requested"
            }.joined(separator: "\n"))
        }
        .presentationCompactAdaptation(.sheet)
        .sheet(isPresented: $showEditInvoice) {
            NavigationStack {
                EditInvoiceView(invoiceID: invoiceID)
            }
        }
        .sheet(isPresented: $vm.showEmailSheet) {
            if let detail = vm.invoiceDetail {
                SendEmailSheet(
                    invoiceID: invoiceID,
                    invoiceNumber: detail.invoice_number,
                    vm: vm,
                    onDismiss: { vm.showEmailSheet = false },
                    isReminder: vm.emailIsReminder
                )
                .presentationDetents([.medium])
            }
        }
        .onChange(of: showEditInvoice) { isPresented in
            if !isPresented {
                Task { await vm.fetchInvoiceDetail(invoiceID: invoiceID) }
            }
        }
    }
}

// MARK: - Date Info Card
struct DateInfoCardZara: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.sMutedFG)
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.sForeground)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Item Row Card
struct ItemRowCardZara: View {
    let item: InvoiceItemDetail
    var itemName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(itemName ?? "Item #\(item.item_id)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.sForeground)

                    Text("Qty: \(item.qty)")
                        .font(.system(size: 11))
                        .foregroundColor(.sMutedFG)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(Money.text(item.total))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.sForeground)

                    Text("\(Money.text(item.rate)) each")
                        .font(.system(size: 11))
                        .foregroundColor(.sMutedFG)
                }
            }

            if item.discount > 0 || item.tax_rate > 0 {
                VStack(spacing: 4) {
                    if item.discount > 0 {
                        summaryRow(label: "Discount", value: -item.discount)
                    }

                    if item.tax_rate > 0 {
                        let taxAmount =
                            (item.total / (1 + item.tax_rate / 100))
                            * (item.tax_rate / 100)
                        summaryRow(label: "Tax (\(item.tax_rate)%)", value: taxAmount)
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(14)
        .background(Color.sCard)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.sBorder, lineWidth: 0.5))
        .cornerRadius(10)
    }

    private func summaryRow(label: String, value: Double) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.sMutedFG)
            Spacer()
            Text(Money.text(value))
                .font(.system(size: 11))
                .foregroundColor(.sMutedFG)
        }
    }
}

// MARK: - Summary Row Item
struct SummaryRowItemZara: View {
    let label: String
    let value: Double
    let isTotal: Bool

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
