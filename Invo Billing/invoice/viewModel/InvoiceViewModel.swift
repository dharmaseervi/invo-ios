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

    // MARK: - UI State
    @Published var isLoading = false
    @Published var showAlert = false
    @Published var errorMessage: String?
    @Published var showSuccessAlert = false
    @Published var successMessage = ""

    // MARK: - Invoice Data
    @Published var invoices: [InvoiceResponse] = []
    @Published var invoiceDetail: InvoiceDetailResponse?
    @Published var isFetchingList = false
    @Published var isFetchingDetail = false
    @Published var showScanner = false
    @Published var invoiceNumber: String = "Auto-generated"

    // MARK: - Address State
    @Published var billingAddress: AddressFormModel = .empty(type: "billing")
    @Published var shippingAddress: AddressFormModel = .empty(type: "shipping")

    @Published var isShippingSameAsBilling: Bool = false {
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
    @Published var isSendingEmail = false
    @Published var emailSentSuccess = false


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
        subtotal + tax
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

    func sendInvoiceEmail(invoiceID: Int, toEmail: String, toName: String) async {
        isSendingEmail = true
        defer { Task { @MainActor in isSendingEmail = false } }
        
        do {
            try await emailService.sendInvoiceEmail(
                invoiceID: invoiceID,
                toEmail: toEmail,
                toName: toName,
                token: SessionManager.shared.token ?? ""  // your existing token property
            )
            await MainActor.run { emailSentSuccess = true }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showAlert = true
            }
        }
    }
    
    func loadClientAddresses() async {
        isLoadingAddresses = true
        defer { isLoadingAddresses = false }
        guard let client = selectedClient else { return }

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

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let payload = InvoiceRequestDTO(
            company_id: SessionManager.shared.selectedCompanyId ?? 0,
            client_id: client.id,
            invoice_date: formatter.string(from: invoiceDate),
            due_date: formatter.string(from: dueDate),
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
    func fetchInvoices(
        companyID: Int? = nil,
        clientID: Int? = nil,
        limit: Int = 100,
        offset: Int = 0
    ) async {
        isFetchingList = true
        defer { isFetchingList = false }

        do {
            let response = try await service.getInvoices(
                companyID: companyID ?? SessionManager.shared.selectedCompanyId,
                clientID: clientID,
                limit: limit,
                offset: offset
            )
            invoices = response.data
        } catch let error as NSError {
            // ✅ Handle 404 "No invoices found" gracefully
            if error.code == 404 {
                invoices = []
                return  // Don't show error alert
            }
            // ... only show error for real errors
        }
    }

    // MARK: - Fetch Invoice Detail
    func fetchInvoiceDetail(invoiceID: Int) async {
        isFetchingDetail = true
        defer { isFetchingDetail = false }

        do {
            invoiceDetail = try await service.getInvoiceByID(invoiceID)
        } catch {
            showError(error.localizedDescription)
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
                .downloadInvoicePDF(invoiceID: invoiceID)
            
            let size = (try? FileManager.default
                .attributesOfItem(atPath: url.path)[.size]) as? Int ?? 0
            
            print("📄 PDF size:", size)
            
            guard size > 0 else {
                throw NSError(domain: "PDF", code: 0, userInfo: [
                    NSLocalizedDescriptionKey: "Empty PDF file"
                ])
            }
            
            await MainActor.run {
                self.pdfURL = url
                self.showPDF = true
            }

            print("✅ PDF (\(copy)) ready")
            
        } catch {
            print("❌ PDF download failed:", error)
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
    }

    private func showError(_ message: String) {
        errorMessage = message
        showAlert = true
    }
}
