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
    var subtotal: Double { items.reduce(0) { $0 + $1.totalBeforeTax } }
    var tax: Double { items.reduce(0) { $0 + $1.taxAmount } }
    var total: Double { max(subtotal + tax - discount, 0) }

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
    func fetchEstimates() async {
        isFetchingList = true
        defer { isFetchingList = false }
        do {
            estimates = try await service.getEstimates(companyID: SessionManager.shared.selectedCompanyId)
        } catch let error as NSError {
            if error.code == 404 {
                estimates = []
                return
            }
            showError(error.localizedDescription)
        } catch {
            showError(error.localizedDescription)
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
