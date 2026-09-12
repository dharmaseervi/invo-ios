import Combine
import Foundation

@MainActor
final class CreateCreditNoteViewModel: ObservableObject {

    // MARK: - Context
    let companyID: Int
    let invoiceID: Int?

    // MARK: - Inputs
    @Published var selectedClient: ClientModel?
    @Published var creditType: CreditNoteType = .adjustment
    @Published var amount: String = ""
    @Published var reason: String = ""
    @Published var notes: String = ""
    @Published var creditDate: Date = Date()

    // Item Return
    @Published var items: [InvoiceLineItem] = []

    // MARK: - Address
    @Published var billingAddress: AddressFormModel = .empty(type: "billing")
    @Published var shippingAddress: AddressFormModel = .empty(type: "shipping")
    @Published var isShippingSameAsBilling = true

    // MARK: - State
    @Published var isLoading = false
    @Published var showAlert = false
    @Published var errorMessage: String?
    @Published var showScanner: Bool = false
    private let addressService = AddressService()

    // MARK: - Init
    init(
        companyID: Int = SessionManager.shared.selectedCompanyId ?? 0,
        invoiceID: Int? = nil
    ) {
        self.companyID = companyID
        self.invoiceID = invoiceID
    }

    // MARK: - Derived Values

    var subtotal: Double {
        switch creditType {
        case .returnItems:
            return items.reduce(0) { partial, line in
                partial + (line.rate * Double(line.qty) - line.discount)
            }
        case .adjustment, .discount:
            return Double(amount) ?? 0
        }
    }

    var tax: Double {
        creditType == .returnItems
            ? items.reduce(0) { $0 + $1.taxAmount }
            : 0
    }

    var total: Double {
        subtotal + tax
    }

    // MARK: - Validation

    var isValid: Bool {
        guard selectedClient != nil else { return false }

        switch creditType {
        case .returnItems:
            return !items.isEmpty
        case .adjustment, .discount:
            return (Double(amount) ?? 0) > 0
        }
    }

    // MARK: - Submit

    func submit() async -> Bool {
        guard let client = selectedClient else {
            showError("Select a client")
            return false
        }

        isLoading = true
        defer { isLoading = false }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        // Pinned: an unpinned formatter follows the device calendar, so a phone set
        // to the Indian National calendar sent 1948-06-21 for 12 September 2026.
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        
        let itemDTOs: [CreateCreditNoteItemDTO]? =
        creditType == .returnItems
        ? items.map {
            CreateCreditNoteItemDTO(
                item_id: $0.item.id,
                qty: Double($0.qty),
                rate: $0.rate,
                discount: $0.discount,
                tax_rate: $0.taxRate
            )
        }
        : nil
        
        let dto = CreateCreditNoteRequestDTO(
            company_id: companyID,
            client_id: client.id,
            invoice_id: invoiceID,
            credit_date: formatter.string(from: creditDate),
            type: creditType.rawValue,
            amount: creditType.usesAmountOnly ? subtotal : nil,
            items: itemDTOs,
            reason: reason.isEmpty ? nil : reason,
            notes: notes.isEmpty ? nil : notes
        )
        
        do {
            try await CreditNoteService.shared.create(dto: dto)
            return true
        } catch {
            showError(error.localizedDescription)
            return false
        }
    }


    // MARK: - Address Loading

    func loadClientAddresses() async {
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
            showError(error.localizedDescription)
        }
    }

    // MARK: - Item Management

    func addItem(_ item: ItemResponse) {
        items.append(
            InvoiceLineItem(
                item: item,
                qty: 1,
                rate: item.price,
                discount: 0,
                taxRate: item.tax_rate ?? 18
            )
        )
    }

    func removeItem(_ line: InvoiceLineItem) {
        items.removeAll { $0.id == line.id }
    }

    // MARK: - Helpers

    private func showError(_ message: String) {
        errorMessage = message
        showAlert = true
    }
}
