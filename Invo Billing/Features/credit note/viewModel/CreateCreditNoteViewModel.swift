import Combine
import Foundation

@MainActor
final class CreateCreditNoteViewModel: ObservableObject {

    // MARK: - Context
    let companyID: Int
    /// The invoice this credit note reduces. It was always nil — nothing opened this
    /// form with an invoice — so a credit note credited the client's ledger but left the
    /// invoice fully owed, and the ageing report went on showing it.
    @Published private(set) var invoiceID: Int?
    @Published private(set) var linkedInvoiceNumber: String?
    /// How many of each item the linked invoice sold, so a return can't exceed it.
    private var soldQty: [Int: Int] = [:]

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

    // MARK: - Starting from an invoice

    /// Fills the form from the invoice it reduces: its client, and for a return its lines,
    /// priced at what the customer was actually charged (the line rate less its share of
    /// the line discount). The server prices a return as qty × rate and ignores any
    /// discount sent, so starting from the charged rate keeps the total shown here and
    /// the total saved the same.
    func link(to invoice: InvoiceDetailResponse) {
        invoiceID = invoice.id
        linkedInvoiceNumber = invoice.invoice_number
        selectedClient = ClientModel(
            id: invoice.client.id, company_id: companyID, name: invoice.client.name,
            address: "", email: "", phone: "", city: "", state: "", pincode: ""
        )
        creditType = .returnItems

        var order: [Int] = []
        var qty: [Int: Int] = [:], charged: [Int: Double] = [:]
        var tax: [Int: Double] = [:], name: [Int: String] = [:]
        for line in invoice.items {
            if qty[line.item_id] == nil { order.append(line.item_id) }
            qty[line.item_id, default: 0] += line.qty
            charged[line.item_id, default: 0] += Double(line.qty) * line.rate - line.discount
            tax[line.item_id] = line.tax_rate
            name[line.item_id] = line.item_name ?? "Item \(line.item_id)"
        }
        soldQty = qty
        items = order.map { id in
            let sold = qty[id] ?? 0
            let unit = sold > 0 ? ((charged[id] ?? 0) / Double(sold) * 100).rounded() / 100 : 0
            let item = ItemResponse(
                id: id, name: name[id] ?? "", category_id: nil, hsn_code: nil, sku: nil,
                unit: nil, description: nil, cost_price: nil, price: unit, quantity: 0,
                low_stock_alert: nil, tax_rate: tax[id], company_id: companyID, user_id: 0
            )
            return InvoiceLineItem(item: item, qty: sold, rate: unit, discount: 0, taxRate: tax[id] ?? 0)
        }
    }

    /// Why a return against the linked invoice can't be saved, if it can't.
    private var linkProblem: String? {
        guard invoiceID != nil, creditType == .returnItems else { return nil }
        let number = linkedInvoiceNumber ?? "the invoice"
        for line in items {
            guard let sold = soldQty[line.item.id] else {
                return "\(line.item.name) isn't on \(number) — only items it sold can be returned against it."
            }
            if line.qty > sold { return "Only \(sold) of \(line.item.name) were sold on \(number)." }
            if line.qty < 1 { return "Remove \(line.item.name), or return at least one." }
        }
        return nil
    }

    // MARK: - Derived Values

    /// The typed credit amount. "1,200" read as nothing, which left Save greyed out with
    /// no reason, so the thousands separator people type is ignored.
    private var amountValue: Double {
        let t = amount.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces)
        guard let v = Double(t), v.isFinite, v >= 0 else { return 0 }
        return v
    }

    var subtotal: Double {
        switch creditType {
        case .returnItems:
            return items.reduce(0) { partial, line in
                partial + (line.rate * Double(line.qty) - line.discount)
            }
        case .adjustment, .discount:
            return amountValue
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
            return amountValue > 0
        }
    }

    // MARK: - Submit

    func submit() async -> Bool {
        guard let client = selectedClient else {
            showError("Select a client")
            return false
        }
        if let problem = linkProblem {
            showError(problem)
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
