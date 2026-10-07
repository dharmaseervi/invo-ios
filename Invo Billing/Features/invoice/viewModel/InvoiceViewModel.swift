import Combine
import Foundation
import UIKit

@MainActor
class InvoiceViewModel: ObservableObject {

    // MARK: - Create Invoice State
    @Published var selectedClient: ClientModel?
    @Published var items: [InvoiceLineItem] = []
    @Published var invoiceDate: Date = Date()
    @Published var dueDate: Date = Date().addingTimeInterval(86400 * 7)
    @Published var discount: Double = 0

    // MARK: - UI State
    @Published var isLoading = false
    @Published var showAlert = false
    @Published var errorMessage: String?
    @Published var showSuccessAlert = false
    @Published var successMessage = ""

    /// Set true in debug preview views — suppresses all network fetches so injected mock data stays intact.
    var previewMode = false

    // MARK: - Invoice Data
    @Published var invoices: [InvoiceResponse] = []
    @Published var invoiceDetail: InvoiceDetailResponse?
    @Published var itemNames: [Int: String] = [:]
    @Published var isFetchingList = false
    @Published var isLoadingMoreInvoices = false
    @Published var hasMoreInvoices = false
    /// True when the last attempt at the next page failed, so the list can offer
    /// another go instead of looking as though it had reached the end.
    @Published var loadMoreFailed = false
    /// Counts and totals for the whole list, from the server.
    @Published var summary: InvoiceSummary = .empty
    /// True when the figures could not be fetched, so the header can say so instead of
    /// showing zeroes as though the business had nothing outstanding.
    @Published var summaryFailed = false
    @Published var isFetchingDetail = false
    @Published var showScanner = false
    @Published var invoiceNumber: String = "Auto-generated"

    // MARK: - Address State
    @Published var billingAddress: AddressFormModel = .empty(type: "billing")
    @Published var shippingAddress: AddressFormModel = .empty(type: "shipping")

    @Published var isShippingSameAsBilling: Bool = true {
        didSet {
            if isShippingSameAsBilling {
                shippingAddress = billingAddress.copyAsShipping()
            }
        }
    }
    @Published var isLoadingAddresses = false
    @Published var pdfDocument: PDFDocument?
    
    
    @Published var pdfURL: URL?
    @Published var showPDF = false
    @Published var showCopyPicker = false
    @Published var selectedInvoiceID: Int?
    
    @Published var showEmailSheet = false
    @Published var selectedEmailInvoiceID: Int?
    @Published var emailIsReminder = false
    @Published var isSendingEmail = false
    @Published var emailSentSuccess = false

    @Published var showOversellConfirm = false
    @Published var oversellItems: [OversellItem] = []
    @Published var pendingIssueInvoiceID: Int?


    private let pdfService = InvoicePDFService()
    private let addressService = AddressService()
    private let emailService = EmailService()

    var onInvoiceCreated: (() -> Void)?

    private let service = InvoiceService()

    // MARK: - Computed Totals (UI ONLY)
    //
    // Worked out by the shared Totals code, which mirrors the server line for line. The
    // old sum here was subtotal + tax - discount, but the server applies an invoice
    // discount before tax and spreads it across the lines — so with any discount the
    // figure quoted on this screen was not the figure saved on the invoice.
    private var computed: InvoiceTotals {
        Totals.compute(
            lines: items.map {
                Totals.Line(qty: $0.qty, rate: $0.rate, discount: $0.discount, taxRate: $0.taxRate)
            },
            invoiceDiscount: discount
        )
    }

    var subtotal: Double { computed.subtotal }

    var tax: Double { computed.tax }

    var total: Double { computed.total }

    // MARK: - Validation
    var isValid: Bool {
        selectedClient != nil && !items.isEmpty
    }

    // MARK: - Line Item Management
    func addItem(_ item: ItemResponse) {
        let line = InvoiceLineItem(
            item: item,
            qty: 1,
            rate: item.price,
            discount: 0,
            taxRate: item.tax_rate ?? 18
        )
        items.append(line)
    }

    func updateItem(_ updated: InvoiceLineItem) {
        if let index = items.firstIndex(where: { $0.id == updated.id }) {
            items[index] = updated
        }
    }

    func removeItem(_ line: InvoiceLineItem) {
        items.removeAll { $0.id == line.id }
    }

    // MARK: - Save Client Addresses (REQUIRED before invoice)
    func saveClientAddressesIfNeeded() async -> Bool {
        guard let client = selectedClient else {
            showError("Please select a client")
            return false
        }

        // Quick sale accounts (Cash/UPI) never need an address
        if client.isQuickSaleAccount { return true }

        if billingAddress.line1.isEmpty || billingAddress.city.isEmpty {
            showError("Billing address is required")
            return false
        }

        do {
            try await addressService.saveClientAddress(
                clientID: client.id,
                payload: billingAddress.toRequest()
            )

            if !isShippingSameAsBilling {
                try await addressService.saveClientAddress(
                    clientID: client.id,
                    payload: shippingAddress.toRequest()
                )
            }

            return true
        } catch {
            showError(error.localizedDescription)
            return false
        }
    }

    func sendInvoiceEmail(invoiceID: Int, toEmail: String, toName: String, isReminder: Bool = false) async {
        isSendingEmail = true
        defer { isSendingEmail = false }

        do {
            try await emailService.sendInvoiceEmail(
                invoiceID: invoiceID,
                toEmail: toEmail,
                toName: toName,
                token: SessionManager.shared.token ?? "",
                isReminder: isReminder
            )
            emailSentSuccess = true
        } catch {
            errorMessage = error.localizedDescription
            showAlert = true
        }
    }
    
    func loadClientAddresses() async {
        isLoadingAddresses = true
        defer { isLoadingAddresses = false }
        guard let client = selectedClient else { return }
        guard !client.isQuickSaleAccount else { return }

        // Cleared first, and only filled from a reply that still matches the client on
        // screen. Before, a client with no address on file left the previous client's
        // address in the fields — and createInvoice then saved it onto the new client,
        // so one customer's address was written into another's record and printed on
        // their invoice. Switching clients quickly could do the same with a reply that
        // arrived late.
        let requested = client.id
        billingAddress = .empty(type: "billing")
        shippingAddress = .empty(type: "shipping")
        isShippingSameAsBilling = true

        do {
            let billing = try await addressService.getClientAddress(clientID: requested, type: "billing")
            guard selectedClient?.id == requested else { return }
            if let billing {
                billingAddress = AddressFormModel(from: billing)
            }

            let shipping = try await addressService.getClientAddress(clientID: requested, type: "shipping")
            guard selectedClient?.id == requested else { return }
            if let shipping {
                shippingAddress = AddressFormModel(from: shipping)
                isShippingSameAsBilling = false
            } else {
                isShippingSameAsBilling = true
            }
        } catch {
            // Handle any thrown errors from address service calls
            guard selectedClient?.id == requested else { return }
            showError(error.localizedDescription)
        }
    }

    // MARK: - Create Invoice (Backend Calculates Everything)
    func createInvoice() async -> Bool {
        // Busy from the first tap, not from the create call.
        //
        // isLoading used to be set after the addresses had been saved, which is a
        // round trip or two — so a second tap in that window started a second create
        // and the customer got two identical invoices, both counted and both owed.
        if isLoading { return false }
        isLoading = true
        defer { isLoading = false }

        // 1️⃣ Save addresses FIRST
        let addressesSaved = await saveClientAddressesIfNeeded()
        guard addressesSaved else { return false }

        guard let client = selectedClient else {
            showError("Please select a client")
            return false
        }

        guard !items.isEmpty else {
            showError("Add at least one item")
            return false
        }

        guard dueDate >= invoiceDate else {
            showError("Due date cannot be before the invoice date")
            return false
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        // Pinned: an unpinned formatter follows the device calendar, so a phone set
        // to the Indian National calendar sent 1948-06-21 for 12 September 2026.
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)

        let payload = InvoiceRequestDTO(
            company_id: SessionManager.shared.selectedCompanyId ?? 0,
            client_id: client.id,
            invoice_date: formatter.string(from: invoiceDate),
            due_date: formatter.string(from: dueDate),
            discount: discount,
            items: items.map {
                InvoiceItemRequest(
                    item_id: $0.item.id,
                    qty: $0.qty,
                    rate: $0.rate,
                    discount: $0.discount,
                    tax_rate: $0.taxRate
                )
            }
        )

        do {
            _ = try await service.createInvoices(payload: payload)

            successMessage = "Invoice created successfully"
            showSuccessAlert = true

            clearForm()
            onInvoiceCreated?()

            return true
        } catch {
            showError(error.localizedDescription)
            return false
        }
    }

    func fetchInvoiceNumberPreview() async {
        guard let companyID = SessionManager.shared.selectedCompanyId else {
            return
        }

        do {
            invoiceNumber = try await service.getInvoiceNumberPreview(
                companyID: companyID
            )
        } catch {
            invoiceNumber = "Auto-generated"
        }
    }

    // MARK: - Fetch Invoice List

    /// Page size. The server caps any request at 200.
    private static let invoicePageSize = 50

    /// Paging state. hasMoreInvoices goes false once a page comes back short, which is
    /// what stops the list asking forever at the bottom.
    private var invoiceOffset = 0
    /// Identifies the newest list request. Every reply checks it before touching the
    /// screen, so a slow one cannot land on top of a newer one.
    ///
    /// Comparing the query instead of a counter is not enough: typing "a", deleting it
    /// and typing "a" again makes two requests that look identical, and the first one
    /// coming back last would still be stale.
    private var listRequestID = 0
    private var listCompanyID: Int?
    private var listClientID: Int?
    private var listSearch: String?
    private var listStatus: String?

    func fetchInvoices(
        companyID: Int? = nil,
        clientID: Int? = nil,
        search: String? = nil,
        status: String? = nil,
        limit: Int = invoicePageSize,
        offset: Int = 0
    ) async {
        listRequestID += 1
        let request = listRequestID
        isFetchingList = true

        // Remembered so loadMoreInvoices can continue the same query.
        listCompanyID = companyID
        listClientID = clientID
        listSearch = search
        listStatus = status
        invoiceOffset = 0
        hasMoreInvoices = false

        let company = companyID ?? SessionManager.shared.selectedCompanyId

        // The figures above the list are counted by the server over everything that
        // matches. Added up here they described the loaded page and called it the
        // business: "Outstanding" was the outstanding amount of the latest fifty.
        //
        // Not asked for by a role that is refused it. The card is hidden for them
        // anyway; making the request regardless would spend it to be told 403 and
        // raise summaryFailed, which reads as a fault rather than as a part of the
        // job somebody else does.
        let maySeeTotals = SessionManager.shared.companyRole.canSeeReports
        async let summaryResult = maySeeTotals
            ? try? service.getInvoiceSummary(
                companyID: company, clientID: clientID, search: search
              )
            : nil

        do {
            let response = try await service.getInvoices(
                companyID: company,
                clientID: clientID,
                search: search,
                status: status,
                limit: limit,
                offset: offset
            )
            let newSummary = await summaryResult
            guard request == listRequestID else { return }
            invoices = response.data
            invoiceOffset = response.data.count
            hasMoreInvoices = response.data.count >= limit
            loadMoreFailed = false
            // A summary that failed is cleared rather than left behind: keeping the
            // previous one put one search's totals above another search's rows.
            summary = newSummary ?? .empty
            summaryFailed = maySeeTotals && newSummary == nil
            isFetchingList = false
        } catch let error as NSError {
            guard request == listRequestID else { return }
            isFetchingList = false
            // Handle 404 "No invoices found" gracefully
            if error.code == 404 {
                invoices = []
                summary = await summaryResult ?? .empty
                return
            }
            showError(error.localizedDescription)
        } catch {
            guard request == listRequestID else { return }
            isFetchingList = false
            showError(error.localizedDescription)
        }
    }

    /// Loads the next page as the list nears its end.
    ///
    /// The list previously fetched a fixed first 100 and never advanced the offset, so
    /// past a hundred invoices the older ones vanished from the list and from search —
    /// and the Outstanding total on the summary card silently under-reported what was
    /// actually owed, because it is computed from the loaded rows.
    func loadMoreInvoices(currentItem invoice: InvoiceResponse) async {
        // Not while a previous page is still failing: the Retry row drives that.
        guard !isLoadingMoreInvoices, hasMoreInvoices, !loadMoreFailed else { return }
        guard let index = invoices.firstIndex(where: { $0.id == invoice.id }),
              index >= invoices.count - 10 else { return }

        isLoadingMoreInvoices = true
        defer { isLoadingMoreInvoices = false }

        // The page belongs to this query. If the search or filter changes while it is
        // out, the rows it carries are for a list nobody is looking at any more.
        let request = listRequestID

        do {
            let response = try await service.getInvoices(
                companyID: listCompanyID ?? SessionManager.shared.selectedCompanyId,
                clientID: listClientID,
                search: listSearch,
                status: listStatus,
                limit: Self.invoicePageSize,
                offset: invoiceOffset
            )
            guard request == listRequestID else { return }
            let existing = Set(invoices.map(\.id))
            invoices.append(contentsOf: response.data.filter { !existing.contains($0.id) })
            invoiceOffset += response.data.count
            hasMoreInvoices = response.data.count >= Self.invoicePageSize
            loadMoreFailed = false
        } catch {
            guard request == listRequestID else { return }
            // A failed page must not replace a list that already has content, and must
            // not quietly end the list either: hasMoreInvoices stayed false, so the
            // older invoices were unreachable until the screen was left and reopened,
            // with nothing on screen to say so. The offset is kept and the row at the
            // bottom offers another go.
            loadMoreFailed = true
        }
    }

    /// Another go at the page that failed, from the Retry row at the end of the list.
    func retryLoadMore() async {
        guard !isLoadingMoreInvoices else { return }
        loadMoreFailed = false
        isLoadingMoreInvoices = true
        defer { isLoadingMoreInvoices = false }

        let request = listRequestID

        do {
            let response = try await service.getInvoices(
                companyID: listCompanyID ?? SessionManager.shared.selectedCompanyId,
                clientID: listClientID,
                search: listSearch,
                status: listStatus,
                limit: Self.invoicePageSize,
                offset: invoiceOffset
            )
            guard request == listRequestID else { return }
            let existing = Set(invoices.map(\.id))
            invoices.append(contentsOf: response.data.filter { !existing.contains($0.id) })
            invoiceOffset += response.data.count
            hasMoreInvoices = response.data.count >= Self.invoicePageSize
        } catch {
            guard request == listRequestID else { return }
            loadMoreFailed = true
        }
    }

    // MARK: - Fetch Invoice Detail
    func fetchInvoiceDetail(invoiceID: Int) async {
        guard !previewMode else { return }
        isFetchingDetail = true
        defer { isFetchingDetail = false }

        do {
            let detail = try await service.getInvoiceByID(invoiceID)
            invoiceDetail = detail
            await loadItemNames(for: detail.items)
        } catch {
            showError(error.localizedDescription)
        }
    }

    /// Names for the lines on an invoice.
    ///
    /// The server sends the name with each line, so they are taken from the reply that
    /// is already in hand. This used to fetch them one item at a time, in sequence: a
    /// six-line invoice meant six more round trips before the screen could finish
    /// drawing, every time it was opened. Anything the server left out is still fetched,
    /// so an older server keeps working.
    private func loadItemNames(for items: [InvoiceItemDetail]) async {
        for item in items where itemNames[item.item_id] == nil {
            if let name = item.item_name, !name.isEmpty {
                itemNames[item.item_id] = name
            }
        }
        for item in items where itemNames[item.item_id] == nil {
            if let response = try? await ItemService().getItemByID(item.item_id),
               let name = response.first?.name {
                itemNames[item.item_id] = name
            }
        }
    }
    
    // MARK: - Update invoice status issue
    @MainActor
    func issueInvoice(invoiceID: Int) async {
        isFetchingDetail = true
        defer { isFetchingDetail = false }

        do {
            try await InvoiceService().issueInvoice(invoiceID: invoiceID)
            await fetchInvoiceDetail(invoiceID: invoiceID) // refresh state
        } catch let oversell as OversellError {
            oversellItems = oversell.items
            pendingIssueInvoiceID = invoiceID
            showOversellConfirm = true
        } catch {
            errorMessage = error.localizedDescription
            showAlert = true
        }
    }

    /// Called when the user confirms "Issue anyway" on the oversell warning.
    @MainActor
    func confirmIssueDespiteOversell() async {
        guard let invoiceID = pendingIssueInvoiceID else { return }
        showOversellConfirm = false
        pendingIssueInvoiceID = nil
        oversellItems = []

        isFetchingDetail = true
        defer { isFetchingDetail = false }

        do {
            try await InvoiceService().issueInvoice(invoiceID: invoiceID, force: true)
            await fetchInvoiceDetail(invoiceID: invoiceID)
        } catch {
            errorMessage = error.localizedDescription
            showAlert = true
        }
    }

    // MARK: - QR / Barcode
    func handleScannedCode(_ value: String) {
        guard value.hasPrefix("ITEM_ID:"),
            let id = Int(value.replacingOccurrences(of: "ITEM_ID:", with: ""))
        else {
            return
        }

        Task { await fetchItemByID(id) }
    }

    private func fetchItemByID(_ id: Int) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await ItemService().getItemByID(id)
            guard let item = response.first else {
                showError("Item not found")
                return
            }

            if let index = items.firstIndex(where: { $0.item.id == item.id }) {
                items[index].qty += 1
                return
            }

            addItem(item)
        } catch {
            showError("Failed to fetch item")
        }
    }
    
    func generateInvoicePDFFromServer(
        invoiceID: Int,
        copy: String
    ) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let url = try await InvoicePDFService()
                .downloadInvoicePDF(
                    invoiceID: invoiceID,
                    copy: copy,
                    template: InvoiceTemplatePreference.load()
                )

            let size = (try? FileManager.default
                .attributesOfItem(atPath: url.path)[.size]) as? Int ?? 0

            guard size > 0 else {
                throw NSError(domain: "PDF", code: 0, userInfo: [
                    NSLocalizedDescriptionKey: "Empty PDF file"
                ])
            }

            self.pdfURL = url
            self.showPDF = true

        } catch {
            self.showAlert = true
            self.errorMessage = "Failed to download PDF"
        }
    }

    

    // MARK: - Helpers
    private func clearForm() {
        selectedClient = nil
        items = []
        invoiceDate = Date()
        dueDate = Date().addingTimeInterval(86400 * 7)
        discount = 0
    }

    /// Deletes a draft invoice. Returns true so the caller can dismiss the detail screen,
    /// which would otherwise sit there showing an invoice that no longer exists.
    func deleteInvoice(invoiceID: Int) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        do {
            try await service.deleteInvoice(invoiceID: invoiceID)
            return true
        } catch {
            showError(error.localizedDescription)
            return false
        }
    }

    private func showError(_ message: String) {
        errorMessage = message
        showAlert = true
    }
}

// MARK: - Not losing a half-written invoice

extension InvoiceViewModel {

    /// The form as it stands, in the shape that is kept on disk.
    private var currentDraft: InvoiceDraft? {
        guard let companyID = SessionManager.shared.selectedCompanyId else { return nil }
        return InvoiceDraft(
            companyID: companyID,
            client: selectedClient,
            lines: items.map {
                InvoiceDraft.Line(
                    item: $0.item, qty: $0.qty, rate: $0.rate,
                    discount: $0.discount, taxRate: $0.taxRate
                )
            },
            invoiceDate: invoiceDate,
            dueDate: dueDate,
            discount: discount
        )
    }

    /// Writes the invoice being typed to disk.
    ///
    /// Called as things change and when the app goes to the background. Cheap enough to
    /// do on every change — one small file, written atomically — and that matters more
    /// than being clever: the moment worth surviving is the one nobody saw coming, when
    /// the app is killed on a low-memory phone with no chance to save anything.
    func saveDraft() {
        guard let draft = currentDraft else { return }
        InvoiceDraftStore.save(draft)
    }

    /// Forgets the unfinished invoice for the company in hand.
    func discardDraft() {
        guard let companyID = SessionManager.shared.selectedCompanyId else { return }
        InvoiceDraftStore.discard(companyID: companyID)
    }

    /// An unfinished invoice waiting for this company, if there is one worth offering.
    func pendingDraft() -> InvoiceDraft? {
        guard let companyID = SessionManager.shared.selectedCompanyId else { return nil }
        return InvoiceDraftStore.load(companyID: companyID)
    }

    /// Puts a draft back on the screen, exactly as it was left.
    func restore(_ draft: InvoiceDraft) {
        items = draft.lines.map {
            InvoiceLineItem(
                item: $0.item, qty: $0.qty, rate: $0.rate,
                discount: $0.discount, taxRate: $0.taxRate
            )
        }
        invoiceDate = draft.invoiceDate
        dueDate = draft.dueDate
        discount = draft.discount
        selectedClient = draft.client
    }
}
