//
//  EditInvoiceViewModel.swift
//  Invo Billing
//
//  Created by dharmaseervi on 2/1/26.
//

import Combine
import Foundation

// MARK: - Edit Invoice ViewModel
@MainActor
class EditInvoiceViewModel: ObservableObject {

    // MARK: - Invoice Identity
    @Published var invoiceID: Int = 0
    @Published var invoiceNumber: String = ""
    @Published var invoiceStatus: String = ""
    @Published var canEdit: Bool = false

    // MARK: - Form State (same as InvoiceViewModel)
    @Published var selectedClient: ClientModel?
    @Published var items: [InvoiceLineItem] = []
    @Published var invoiceDate: Date = Date()
    @Published var dueDate: Date = Date().addingTimeInterval(86400 * 7)
    @Published var discount: Double = 0

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

    // MARK: - UI State
    @Published var isLoading = false
    @Published var isLoadingInvoice = false
    @Published var showAlert = false
    @Published var errorMessage: String?
    @Published var showSuccessAlert = false
    @Published var successMessage = ""
    @Published var showScanner = false

    private let service = InvoiceService()
    private let addressService = AddressService()

    // MARK: - Computed Properties (same as InvoiceViewModel)
    var subtotal: Double {
        items.reduce(0) { $0 + $1.totalBeforeTax }
    }

    var tax: Double {
        items.reduce(0) { $0 + $1.taxAmount }
    }

    var total: Double {
        max(subtotal + tax - discount, 0)
    }

    var isValid: Bool {
        selectedClient != nil && !items.isEmpty
    }

    // MARK: - Line Item Management (same as InvoiceViewModel)
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

    // MARK: - Load Existing Invoice
    func loadInvoice(invoiceID: Int) async {
        self.invoiceID = invoiceID
        isLoadingInvoice = true
        defer { isLoadingInvoice = false }

        do {
            // InvoiceDetailResponse has FLAT structure (not nested)
            let detail = try await service.getInvoiceByID(invoiceID)

            // Store status
            invoiceStatus = detail.status.rawValue

            // Check if invoice is draft
            canEdit = detail.status == .draft

            guard canEdit else {
                return  // View will show non-editable state
            }

            // Populate form fields
            invoiceNumber = detail.invoice_number

            // Set client from ClientSummary (only has id and name)
            selectedClient = ClientModel(
                id: detail.client.id,
                company_id: SessionManager.shared.selectedCompanyId ?? 0,
                name: detail.client.name,
                address: "",
                email: "",
                phone: "",
                city: "",
                state: "",
                pincode: ""
            )

            // Parse dates
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"

            if let invDate = formatter.date(
                from: String(detail.invoice_date.prefix(10))
            ) {
                invoiceDate = invDate
            }
            if let dueD = formatter.date(
                from: String(detail.due_date.prefix(10))
            ) {
                dueDate = dueD
            }

            discount = detail.discount

            // Load items - InvoiceItemDetail doesn't have item_name, need to fetch
            await loadInvoiceItems(detail.items)

            // Load addresses
            await loadClientAddresses()

        } catch {
            showError("Failed to load invoice: \(error.localizedDescription)")
        }
    }

    // MARK: - Load Invoice Items with Item Details
    private func loadInvoiceItems(_ invoiceItems: [InvoiceItemDetail]) async {
        var loadedItems: [InvoiceLineItem] = []
        var hadTransientFailure = false

        for item in invoiceItems {
            do {
                // Fetch item details to get name
                let itemResponse = try await ItemService().getItemByID(
                    item.item_id
                )

                if let itemDetail = itemResponse.first {
                    let lineItem = InvoiceLineItem(
                        item: itemDetail,
                        qty: item.qty,
                        rate: item.rate,
                        discount: item.discount,
                        taxRate: item.tax_rate
                    )
                    loadedItems.append(lineItem)
                } else {
                    // Item genuinely no longer exists server-side.
                    loadedItems.append(createPlaceholderLineItem(from: item, reason: "Deleted Item"))
                }
            } catch let error as NSError where error.code == 404 {
                // Item genuinely no longer exists server-side.
                loadedItems.append(createPlaceholderLineItem(from: item, reason: "Deleted Item"))
            } catch {
                // Transient failure (network, decode, server error) — keep the real
                // line data intact and flag it instead of silently mislabeling it "deleted".
                hadTransientFailure = true
                loadedItems.append(createPlaceholderLineItem(from: item, reason: "Item unavailable — pull to refresh"))
            }
        }

        items = loadedItems

        if hadTransientFailure {
            showError("Some item details couldn't be loaded. Pull to refresh before saving so nothing is overwritten.")
        }
    }

    private func createPlaceholderLineItem(
        from item: InvoiceItemDetail,
        reason: String
    ) -> InvoiceLineItem {

        let placeholderItem = ItemResponse(
            id: item.item_id,
            name: reason,
            category_id: 0,
            hsn_code: "",
            sku: "",
            unit: "",
            description: "",
            cost_price: 0,
            price: item.rate,
            quantity: 0,
            low_stock_alert: 0,
            tax_rate: item.tax_rate,
            company_id: SessionManager.shared.selectedCompanyId ?? 0,
            user_id: 0
        )

        return InvoiceLineItem(
            item: placeholderItem,
            qty: item.qty,
            rate: item.rate,
            discount: item.discount,
            taxRate: item.tax_rate
        )
    }

    // MARK: - Load Client Addresses (same pattern as InvoiceViewModel)
    func loadClientAddresses() async {
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
            // Silently handle - addresses might not exist yet
        }
    }

    // MARK: - Save Client Addresses If Needed (same as InvoiceViewModel)
    func saveClientAddressesIfNeeded() async -> Bool {
        guard let client = selectedClient else {
            showError("Please select a client")
            return false
        }

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

    // MARK: - Update Invoice
    func updateInvoice() async -> Bool {
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

        // Save addresses first (same pattern as InvoiceViewModel.createInvoice)
        let addressesSaved = await saveClientAddressesIfNeeded()
        guard addressesSaved else { return false }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let payload = UpdateInvoiceRequestDTO(
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
            try await service.updateInvoice(
                invoiceID: invoiceID,
                payload: payload
            )

            successMessage = "Invoice updated successfully"
            showSuccessAlert = true
            return true
        } catch {
            showError(error.localizedDescription)
            return false
        }
    }

    // MARK: - QR / Barcode (same as InvoiceViewModel)
    func handleScannedCode(_ value: String) {
        guard value.hasPrefix("ITEM_ID:"),
            let id = Int(value.replacingOccurrences(of: "ITEM_ID:", with: ""))
        else { return }

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

            // Same pattern as InvoiceViewModel
            if let index = items.firstIndex(where: { $0.item.id == item.id }) {
                items[index].qty += 1
                return
            }

            addItem(item)
        } catch {
            showError("Failed to fetch item")
        }
    }

    private func showError(_ message: String) {
        errorMessage = message
        showAlert = true
    }
}

// MARK: - Update Invoice DTO
struct UpdateInvoiceRequestDTO: Codable {
    let client_id: Int
    let invoice_date: String
    let due_date: String
    let discount: Double
    let items: [InvoiceItemRequest]
}

