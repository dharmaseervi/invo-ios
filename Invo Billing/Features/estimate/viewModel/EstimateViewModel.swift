import Combine
import Foundation

@MainActor
final class EstimateViewModel: ObservableObject {

    // MARK: - Create/Edit Form State
    @Published var editingEstimateID: Int?
    @Published var selectedClient: ClientModel?
    @Published var items: [InvoiceLineItem] = []
    @Published var estimateDate: Date = Date()
    @Published var expiryDate: Date = Date().addingTimeInterval(86400 * 14)
    @Published var hasExpiryDate: Bool = true
    @Published var discount: Double = 0
    @Published var estimateNumber: String = "Auto-generated"

    // MARK: - List / Detail State
    @Published var estimates: [EstimateResponse] = []
    @Published var estimateDetail: EstimateDetailResponse?
    @Published var itemNames: [Int: String] = [:]
    @Published var isFetchingList = false
    @Published var isFetchingDetail = false

    /// What the list is searched for. Sent to the server, because the phone only holds
    /// the pages it has loaded and filtering those locally would answer "no results"
    /// for an estimate that is simply further down.
    @Published var searchQuery = ""
    /// A failed list load, kept on screen so it is not mistaken for an empty shop.
    @Published var listError: String?
    @Published var isLoadingMore = false
    @Published var loadMoreFailed = false
    @Published var hasMoreEstimates = false

    // MARK: - UI State
    @Published var isLoading = false
    @Published var showAlert = false
    @Published var errorMessage: String?
    @Published var showSuccessAlert = false
    @Published var successMessage = ""
    @Published var showScanner = false
    @Published var pdfURL: URL?
    @Published var showPDF = false

    private let service = EstimateService()
    var onEstimateCreated: (() -> Void)?

    // MARK: - Computed Totals
    // The server's arithmetic, shared with invoices: an estimate's discount is applied
    // before tax, apportioned across the lines. It matters doubly here, because an
    // estimate turns into an invoice — a quote that added up differently from the bill
    // that followed it is a conversation with a customer nobody wants to have.
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

    var isValid: Bool {
        selectedClient != nil && !items.isEmpty
    }

    // MARK: - Line Items
    func addItem(_ item: ItemResponse) {
        items.append(InvoiceLineItem(item: item, qty: 1, rate: item.price, discount: 0, taxRate: item.tax_rate ?? 18))
    }

    func updateItem(_ updated: InvoiceLineItem) {
        if let index = items.firstIndex(where: { $0.id == updated.id }) {
            items[index] = updated
        }
    }

    func removeItem(_ line: InvoiceLineItem) {
        items.removeAll { $0.id == line.id }
    }

    func handleScannedCode(_ value: String) {
        guard value.hasPrefix("ITEM_ID:"),
              let id = Int(value.replacingOccurrences(of: "ITEM_ID:", with: ""))
        else { return }
        Task { await fetchItemByID(id) }
    }

    private func fetchItemByID(_ id: Int) async {
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

    // MARK: - Number Preview
    func fetchEstimateNumberPreview() async {
        guard let companyID = SessionManager.shared.selectedCompanyId else { return }
        do {
            estimateNumber = try await service.getNumberPreview(companyID: companyID)
        } catch {
            estimateNumber = "Auto-generated"
        }
    }

    // MARK: - Create
    func createEstimate() async -> Bool {
        guard let client = selectedClient else {
            showError("Please select a client")
            return false
        }
        guard !items.isEmpty else {
            showError("Add at least one item")
            return false
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        // Pinned: an unpinned formatter follows the device calendar, so a phone set
        // to the Indian National calendar sent 1948-06-21 for 12 September 2026.
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)

        let payload = EstimateRequestDTO(
            company_id: SessionManager.shared.selectedCompanyId ?? 0,
            client_id: client.id,
            estimate_date: formatter.string(from: estimateDate),
            expiry_date: hasExpiryDate ? formatter.string(from: expiryDate) : nil,
            discount: discount,
            items: items.map {
                InvoiceItemRequest(item_id: $0.item.id, qty: $0.qty, rate: $0.rate, discount: $0.discount, tax_rate: $0.taxRate)
            }
        )

        isLoading = true
        defer { isLoading = false }

        do {
            _ = try await service.createEstimate(payload: payload)
            successMessage = "Estimate created successfully"
            showSuccessAlert = true
            clearForm()
            onEstimateCreated?()
            return true
        } catch {
            showError(error.localizedDescription)
            return false
        }
    }

    // MARK: - Load for Edit (drafts only)
    func loadEstimateForEdit(estimateID: Int) async {
        isFetchingDetail = true
        defer { isFetchingDetail = false }

        do {
            let detail = try await service.getEstimateByID(estimateID)
            editingEstimateID = estimateID
            estimateNumber = detail.estimate_number
            discount = detail.discount

            if let companyID = SessionManager.shared.selectedCompanyId,
               let clients = try? await ClientServices().loadClients(for: companyID) {
                selectedClient = clients.first { $0.id == detail.client.id }
            }

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            // Pinned: an unpinned formatter follows the device calendar, so a phone set
            // to the Indian National calendar sent 1948-06-21 for 12 September 2026.
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.calendar = Calendar(identifier: .gregorian)
            if let date = formatter.date(from: detail.estimate_date) {
                estimateDate = date
            }
            if let expiry = detail.expiry_date, let date = formatter.date(from: expiry) {
                expiryDate = date
                hasExpiryDate = true
            } else {
                hasExpiryDate = false
            }

            await loadLineItemsForEdit(detail.items)
        } catch {
            showError("Failed to load estimate")
        }
    }

    private func loadLineItemsForEdit(_ estimateItems: [EstimateItemDetail]) async {
        var loaded: [InvoiceLineItem] = []
        for line in estimateItems {
            if let response = try? await ItemService().getItemByID(line.item_id),
               let itemDetail = response.first {
                loaded.append(InvoiceLineItem(
                    item: itemDetail,
                    qty: line.qty,
                    rate: line.rate,
                    discount: line.discount,
                    taxRate: line.tax_rate
                ))
            }
        }
        items = loaded
    }

    // MARK: - Update (drafts only)
    func updateEstimateChanges() async -> Bool {
        guard let estimateID = editingEstimateID else { return false }
        guard let client = selectedClient else {
            showError("Please select a client")
            return false
        }
        guard !items.isEmpty else {
            showError("Add at least one item")
            return false
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        // Pinned: an unpinned formatter follows the device calendar, so a phone set
        // to the Indian National calendar sent 1948-06-21 for 12 September 2026.
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)

        let payload = UpdateEstimateRequestDTO(
            client_id: client.id,
            estimate_date: formatter.string(from: estimateDate),
            expiry_date: hasExpiryDate ? formatter.string(from: expiryDate) : nil,
            discount: discount,
            items: items.map {
                InvoiceItemRequest(item_id: $0.item.id, qty: $0.qty, rate: $0.rate, discount: $0.discount, tax_rate: $0.taxRate)
            }
        )

        isLoading = true
        defer { isLoading = false }

        do {
            try await service.updateEstimate(id: estimateID, payload: payload)
            successMessage = "Estimate updated"
            showSuccessAlert = true
            return true
        } catch {
            showError(error.localizedDescription)
            return false
        }
    }

    // MARK: - Fetch List

    /// How many estimates a page holds. Enough that most shops never reach the end of
    /// the first one, small enough that opening the screen is not a wait.
    private static let pageSize = 25

    /// The newest list load, so a reply for an old search is not shown under a new one.
    private var listRequestCounter = 0
    private var currentListRequest = 0

    /// Reloads the list from the top. Called on appear and whenever the search changes.
    func fetchEstimates() async {
        listRequestCounter += 1
        let request = listRequestCounter
        currentListRequest = request

        isFetchingList = true
        listError = nil

        do {
            let page = try await service.getEstimates(
                companyID: SessionManager.shared.selectedCompanyId,
                search: searchQuery.isEmpty ? nil : searchQuery,
                limit: Self.pageSize,
                offset: 0
            )
            guard request == currentListRequest else { return }
            estimates = page
            hasMoreEstimates = page.count == Self.pageSize
            loadMoreFailed = false
            isFetchingList = false
        } catch let error as NSError where error.code == 404 {
            guard request == currentListRequest else { return }
            estimates = []
            hasMoreEstimates = false
            isFetchingList = false
        } catch {
            guard request == currentListRequest else { return }
            // Kept on the screen rather than only in an alert. A dismissed alert left
            // the empty state behind, so a dropped connection read as "no estimates
            // yet" to a shop that has hundreds.
            listError = error.localizedDescription
            isFetchingList = false
        }
    }

    /// Fetches the next page when the list is nearly scrolled to the end.
    func loadMoreIfNeeded(currentEstimate estimate: EstimateResponse) async {
        // Five from the bottom, so the next page is usually there before it is needed.
        guard estimate.id == estimates.suffix(5).first?.id else { return }
        await loadNextPage()
    }

    /// Clears the paging failure and tries the same page again.
    func retryLoadMore() async {
        loadMoreFailed = false
        await loadNextPage()
    }

    private func loadNextPage() async {
        guard hasMoreEstimates, !isLoadingMore, !loadMoreFailed else { return }

        let request = currentListRequest
        isLoadingMore = true

        do {
            let page = try await service.getEstimates(
                companyID: SessionManager.shared.selectedCompanyId,
                search: searchQuery.isEmpty ? nil : searchQuery,
                limit: Self.pageSize,
                offset: estimates.count
            )
            // A page that belongs to a search that has since changed is dropped; the
            // reload for the new search is already on its way.
            guard request == currentListRequest else { return }
            // Appending by id rather than wholesale, so a row that both pages happened
            // to contain is not shown twice.
            let known = Set(estimates.map(\.id))
            estimates.append(contentsOf: page.filter { !known.contains($0.id) })
            hasMoreEstimates = page.count == Self.pageSize
            isLoadingMore = false
        } catch {
            guard request == currentListRequest else { return }
            // Paging stops but is not given up on: the rest is still there, and the
            // list offers to try again rather than quietly ending.
            loadMoreFailed = true
            isLoadingMore = false
        }
    }

    // MARK: - Fetch Detail
    func fetchEstimateDetail(estimateID: Int) async {
        isFetchingDetail = true
        defer { isFetchingDetail = false }
        do {
            let detail = try await service.getEstimateByID(estimateID)
            estimateDetail = detail
            await loadItemNames(for: detail.items)
        } catch {
            showError(error.localizedDescription)
        }
    }

    private func loadItemNames(for items: [EstimateItemDetail]) async {
        for item in items where itemNames[item.item_id] == nil {
            if let response = try? await ItemService().getItemByID(item.item_id),
               let name = response.first?.name {
                itemNames[item.item_id] = name
            }
        }
    }

    // MARK: - Status transitions
    func markAsSent(estimateID: Int) async {
        await updateStatus(estimateID: estimateID, status: "sent")
    }
    func markAsAccepted(estimateID: Int) async {
        await updateStatus(estimateID: estimateID, status: "accepted")
    }
    func markAsRejected(estimateID: Int) async {
        await updateStatus(estimateID: estimateID, status: "rejected")
    }

    private func updateStatus(estimateID: Int, status: String) async {
        do {
            try await service.updateStatus(id: estimateID, status: status)
            await fetchEstimateDetail(estimateID: estimateID)
        } catch {
            showError(error.localizedDescription)
        }
    }

    // MARK: - Convert to Invoice
    @Published var convertedInvoiceID: Int?

    func convertToInvoice(estimateID: Int) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await service.convertToInvoice(id: estimateID)
            convertedInvoiceID = result.invoice_id
            successMessage = "Converted to invoice \(result.invoice_number)"
            showSuccessAlert = true
            await fetchEstimateDetail(estimateID: estimateID)
        } catch {
            showError(error.localizedDescription)
        }
    }

    // MARK: - PDF
    func generateEstimatePDF(estimateID: Int) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let url = try await service.downloadEstimatePDF(
                estimateID: estimateID,
                template: InvoiceTemplatePreference.load()
            )
            pdfURL = url
            showPDF = true
        } catch {
            showError("Failed to download PDF")
        }
    }

    // MARK: - Helpers
    private func clearForm() {
        selectedClient = nil
        items = []
        estimateDate = Date()
        expiryDate = Date().addingTimeInterval(86400 * 14)
        discount = 0
    }

    private func showError(_ message: String) {
        errorMessage = message
        showAlert = true
    }
}
