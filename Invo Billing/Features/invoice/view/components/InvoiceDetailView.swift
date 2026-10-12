import SwiftUI

struct InvoiceDetailView: View {
    let invoiceID: Int
    @ObservedObject var vm: InvoiceViewModel
    @Environment(\.dismiss) var dismiss
    @State private var showRecordPayment = false
    @State private var showEditInvoice = false
    @State private var showCreditNote = false
    @State private var showDeleteConfirmation = false
    @State private var showCancelConfirmation = false
    @State private var isDeleting = false
    @State private var isCancelling = false
    @State private var isDuplicating = false
    @State private var shareLink: String?
    @State private var showShareSheet = false
    // Check if invoice is draft
    private var isDraft: Bool {
        vm.invoiceDetail?.status.rawValue == "draft"
    }

    private func statusConfig(for detail: InvoiceDetailResponse) -> (label: String, color: Color) {
        if detail.is_overdue { return ("Overdue", .sDestructive) }
        switch detail.status {
        case .paid:      return ("Paid",      .sSuccess)
        case .pending:   return ("Pending",   .sWarning)
        case .partial:   return ("Partial",   .sWarning)
        case .draft:     return ("Draft",     .sNeutral)
        case .issued:    return ("Issued",    Color.sAccent)
        case .cancelled: return ("Cancelled", .sNeutral)
        case .sent:      return ("Sent",      .sNeutral)
        case .overdue:   return ("Overdue",   .sDestructive)
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

                            if let phone = detail.client.phone, !phone.isEmpty {
                                Button(action: {
                                    WhatsApp.open(
                                        phone: phone,
                                        message: "Invoice \(detail.invoice_number) for ₹\(String(format: "%.0f", detail.total)) is ready. Please review and make the payment at your earliest convenience."
                                    )
                                }) {
                                    Label("Send via WhatsApp", systemImage: "message")
                                }
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

                        // Goods back or a price corrected, against this invoice so its
                        // balance goes down. Only an issued invoice can be credited.
                        if let detail = vm.invoiceDetail,
                           [.issued, .partial, .paid].contains(detail.status) {
                            Button(action: { showCreditNote = true }) {
                                Label("Credit note", systemImage: "arrow.uturn.backward.circle")
                            }
                        }

                        Button {
                            Task { await duplicateInvoice() }
                        } label: {
                            Label(isDuplicating ? "Duplicating…" : "Duplicate invoice", systemImage: "doc.on.doc")
                        }
                        .disabled(isDuplicating)

                        if let detail = vm.invoiceDetail, detail.status != .draft, detail.status != .cancelled {
                            Button {
                                Task { await generateShareLink() }
                            } label: {
                                Label("Share link", systemImage: "link")
                            }
                        }

                        // Cancel voids the invoice and zeroes the ledger entry.
                        // Only available on issued/partial — drafts can simply be deleted.
                        if let detail = vm.invoiceDetail,
                           [.issued, .partial].contains(detail.status) {
                            Divider()
                            Button(role: .destructive, action: { showCancelConfirmation = true }) {
                                Label("Cancel invoice", systemImage: "xmark.circle")
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
                            .font(.subheadline)
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
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundColor(.sAccent)
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(detail.client.name)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundColor(.sForeground)
                                        HStack(spacing: 6) {
                                            Text(detail.invoice_number)
                                                .font(.subheadline)
                                                .foregroundColor(.sMutedFG)
                                            if let docType = detail.doc_type, !docType.isEmpty {
                                                Text(docType.capitalized)
                                                    .font(.caption.weight(.semibold))
                                                    .foregroundColor(.sAccent)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Capsule().fill(Color.sAccentMuted))
                                            }
                                        }
                                    }

                                    Spacer()

                                    let config = statusConfig(for: detail)
                                    Text(config.label)
                                        .font(.caption.weight(.medium))
                                        .foregroundColor(config.color)
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 4)
                                        .background(Capsule().fill(config.color.opacity(0.1)))
                                }

                                Rectangle().fill(Color.sBorder).frame(height: 0.5)

                                HStack(alignment: .firstTextBaseline) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("Total amount")
                                            .font(.caption)
                                            .foregroundColor(.sMutedFG)
                                        Text(Money.text(detail.total)).moneyLine()
                                            .font(.title2.weight(.bold))
                                            .foregroundColor(.sForeground)
                                    }
                                    Spacer()
                                    if detail.paid_amount > 0 && detail.status != .paid {
                                        VStack(alignment: .trailing, spacing: 3) {
                                            Text("Remaining")
                                                .font(.caption)
                                                .foregroundColor(.sMutedFG)
                                            Text(Money.text(detail.remaining_amount)).moneyLine()
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundColor(.sWarning)
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
                                        .font(.caption)
                                        .foregroundColor(.sMutedFG)
                                }
                            }
                            .padding(AppSpacing.card)
                            .background(Color.sCard)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.sBorder, lineWidth: 0.5))
                            .cornerRadius(14)
                            .padding(.horizontal, AppSpacing.page)
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
                                        .font(.subheadline.weight(.semibold))
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
                                        .font(.subheadline.weight(.semibold))
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
                                        .font(.subheadline.weight(.semibold))
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
                                        .font(.subheadline.weight(.semibold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(Color.sPrimary)
                                        .foregroundColor(.sAccentFG)
                                        .cornerRadius(10)
                                    }
                                }
                            }
                            .padding(.horizontal, AppSpacing.page)
                            .padding(.top, 16)

                            // MARK: - Dates Section
                            VStack(alignment: .leading, spacing: 0) {
                                Text("Dates")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.sMutedFG)
                                    .padding(.horizontal, AppSpacing.page)
                                    .padding(.bottom, 10)

                                HStack(spacing: 0) {
                                    DateInfoCardZara(label: "Issue date", value: detail.invoice_date)
                                    Rectangle().fill(Color.sBorder).frame(width: 0.5)
                                    DateInfoCardZara(label: "Due date", value: detail.due_date)
                                }
                                .background(Color.sCard)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.sBorder, lineWidth: 0.5))
                                .cornerRadius(10)
                                .padding(.horizontal, AppSpacing.page)
                                .padding(.bottom, 20)
                            }

                            // MARK: - Line Items Section
                            VStack(alignment: .leading, spacing: 0) {
                                Text("Line items")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.sMutedFG)
                                    .padding(.horizontal, AppSpacing.page)
                                    .padding(.bottom, 10)

                                VStack(spacing: 10) {
                                    ForEach(Array(detail.items.enumerated()), id: \.element.id) { index, item in
                                        ItemRowCardZara(
                                            item: item,
                                            itemName: vm.itemNames[item.item_id]
                                        )
                                    }
                                }
                                .padding(.horizontal, AppSpacing.page)
                                .padding(.bottom, 20)
                            }

                            // MARK: - Summary Section
                            VStack(alignment: .leading, spacing: 0) {
                                Text("Summary")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.sMutedFG)
                                    .padding(.horizontal, AppSpacing.page)
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

                                    if let tdsRate = detail.tds_rate, tdsRate > 0,
                                       let tdsAmount = detail.tds_amount {
                                        SummaryRowItemZara(label: "Invoice total", value: detail.total, isTotal: false)
                                        Rectangle().fill(Color.sBorder).frame(height: 0.5).padding(.horizontal, 14)
                                        SummaryRowItemZara(
                                            label: "TDS @ \(tdsRate.formatted(.number.precision(.fractionLength(0...1))))%",
                                            value: -tdsAmount,
                                            isTotal: false
                                        )
                                        Rectangle().fill(Color.sBorder).frame(height: 0.5).padding(.horizontal, 14)
                                        SummaryRowItemZara(
                                            label: "Net receivable",
                                            value: detail.total - tdsAmount,
                                            isTotal: true
                                        )
                                    } else {
                                        SummaryRowItemZara(label: "Total", value: detail.total, isTotal: true)
                                    }
                                }
                                .background(Color.sCard)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.sBorder, lineWidth: 0.5))
                                .cornerRadius(10)
                                .padding(.horizontal, AppSpacing.page)
                                .padding(.bottom, 40)
                            }
                        }
                    }
                } else if let error = vm.errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title)
                            .foregroundColor(.sDestructive)

                        Text("Error loading invoice")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.sForeground)

                        Text(error)
                            .font(.footnote)
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
                            .font(.subheadline)
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
        .sheet(isPresented: $showCreditNote, onDismiss: {
            // A credit note changes the balance shown here.
            Task { await vm.fetchInvoiceDetail(invoiceID: invoiceID) }
        }) {
            if let detail = vm.invoiceDetail {
                NavigationStack {
                    CreateCreditNoteView(invoice: detail)
                }
            }
        }
        .confirmationDialog(
            "Cancel this invoice?",
            isPresented: $showCancelConfirmation,
            titleVisibility: .visible
        ) {
            Button("Cancel invoice", role: .destructive) {
                Task {
                    isCancelling = true
                    let cancelled = await vm.cancelInvoice(invoiceID: invoiceID)
                    isCancelling = false
                    if cancelled {
                        await vm.fetchInvoiceDetail(invoiceID: invoiceID)
                    }
                }
            }
            Button("Keep invoice", role: .cancel) {}
        } message: {
            Text("The invoice will be voided and the customer will no longer owe this amount. This cannot be undone.")
        }
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
        .sheet(isPresented: $showShareSheet) {
            if let link = shareLink {
                ShareSheet(items: [link])
            }
        }
    }

    private func duplicateInvoice() async {
        isDuplicating = true
        defer { isDuplicating = false }
        guard let token = SessionManager.shared.token else { return }
        var req = URLRequest(url: URL(string: "\(AppEnvironment.baseURL)/invoices/\(invoiceID)/duplicate")!)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let newID = json["invoice_id"] as? Int else {
            vm.errorMessage = "Failed to duplicate invoice"
            vm.showAlert = true
            return
        }
        await vm.fetchInvoices()
        vm.successMessage = "Duplicate created — invoice #\(newID)"
        vm.showSuccessAlert = true
    }

    private func generateShareLink() async {
        guard let token = SessionManager.shared.token else { return }
        var req = URLRequest(url: URL(string: "\(AppEnvironment.baseURL)/invoices/\(invoiceID)/share")!)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let shareToken = json["token"] as? String else {
            vm.errorMessage = "Failed to generate share link"
            vm.showAlert = true
            return
        }
        // Public URL the recipient opens in their browser
        shareLink = "\(AppEnvironment.baseURL)/public/invoices/\(shareToken)"
        showShareSheet = true
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}

// MARK: - Date Info Card
struct DateInfoCardZara: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundColor(.sMutedFG)
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.sForeground)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppSpacing.page)
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
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.sForeground)

                    HStack(spacing: 8) {
                        Text("Qty: \(item.qty)")
                            .font(.caption)
                            .foregroundColor(.sMutedFG)
                        if let hsn = item.hsn_code, !hsn.isEmpty {
                            Text("HSN: \(hsn)")
                                .font(.caption)
                                .foregroundColor(.sMutedFG)
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(Money.text(item.total)).moneyLine()
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.sForeground)

                    Text("\(Money.text(item.rate)) each")
                        .font(.caption)
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
                .font(.caption)
                .foregroundColor(.sMutedFG)
            Spacer()
            Text(Money.text(value)).moneyLine()
                .font(.caption)
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
                .font(isTotal ? .headline : .subheadline)
                .foregroundColor(.sForeground)

            Spacer()

            Text(Money.text(value)).moneyLine()
                .font(isTotal ? .headline : .subheadline)
                .foregroundColor(.sForeground)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}
