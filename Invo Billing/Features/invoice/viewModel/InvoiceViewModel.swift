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

    // MARK: - Invoice Data
    @Published var invoices: [InvoiceResponse] = []
    @Published var invoiceDetail: InvoiceDetailResponse?
    @Published var itemNames: [Int: String] = [:]
    @Published var isFetchingList = false
    @Published var isLoadingMoreInvoices = false
    @Published var hasMoreInvoices = false
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
    var subtotal: Double {
        items.reduce(0) { $0 + $1.totalBeforeTax }
    }

    var tax: Double {
        items.reduce(0) { $0 + $1.taxAmount }
    }

    var total: Double {
        max(subtotal + tax - discount, 0)
    }

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

        do {
            if let billing = try await addressService.getClientAddress(
                clientID: client.id,
                type: "billing"
            ) {
                billingAddress = AddressFormModel(from: billing)
            }

            if let shipping = try await addressService.getClientAddress(
                clientID: client.id,
                type: "shipping"
            ) {
                shippingAddress = AddressFormModel(from: shipping)
                isShippingSameAsBilling = false
            } else {
                isShippingSameAsBilling = true
            }
        } catch {
            // Handle any thrown errors from address service calls
            showError(error.localizedDescription)
        }
    }

    // MARK: - Create Invoice (Backend Calculates Everything)
    func createInvoice() async -> Bool {

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

        isLoading = true
        defer { isLoading = false }

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
    private var listCompanyID: Int?
    private var listClientID: Int?

    func fetchInvoices(
        companyID: Int? = nil,
        clientID: Int? = nil,
        limit: Int = invoicePageSize,
        offset: Int = 0
    ) async {
        isFetchingList = true
        defer { isFetchingList = false }

        // Remembered so loadMoreInvoices can continue the same query.
        listCompanyID = companyID
        listClientID = clientID
        invoiceOffset = 0
        hasMoreInvoices = false

        do {
            let response = try await service.getInvoices(
                companyID: companyID ?? SessionManager.shared.selectedCompanyId,
                clientID: clientID,
                limit: limit,
                offset: offset
            )
            invoices = response.data
            invoiceOffset = response.data.count
            hasMoreInvoices = response.data.count >= limit
        } catch let error as NSError {
            // Handle 404 "No invoices found" gracefully
            if error.code == 404 {
                invoices = []
                return
            }
            showError(error.localizedDescription)
        } catch {
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
        guard !isLoadingMoreInvoices, hasMoreInvoices else { return }
        guard let index = invoices.firstIndex(where: { $0.id == invoice.id }),
              index >= invoices.count - 10 else { return }

        isLoadingMoreInvoices = true
        defer { isLoadingMoreInvoices = false }

        do {
            let response = try await service.getInvoices(
                companyID: listCompanyID ?? SessionManager.shared.selectedCompanyId,
                clientID: listClientID,
                limit: Self.invoicePageSize,
                offset: invoiceOffset
            )
            let existing = Set(invoices.map(\.id))
            invoices.append(contentsOf: response.data.filter { !existing.contains($0.id) })
            invoiceOffset += response.data.count
            hasMoreInvoices = response.data.count >= Self.invoicePageSize
        } catch {
            // A failed page should not replace a list that already has content.
            hasMoreInvoices = false
        }
    }

    // MARK: - Fetch Invoice Detail
    func fetchInvoiceDetail(invoiceID: Int) async {
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

    private func loadItemNames(for items: [InvoiceItemDetail]) async {
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
