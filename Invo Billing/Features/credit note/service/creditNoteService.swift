import Foundation

final class CreditNoteService {
    
    static let shared = CreditNoteService()
    private let baseURL = AppEnvironment.baseURL
    
    // MARK: - Get All Credit Notes
    /// One page of credit notes. limit 0 asks for the lot, which is what this screen
    /// used to do on every visit.
    func fetchAll(
        search: String? = nil,
        type: String? = nil,
        limit: Int = 0,
        offset: Int = 0
    ) async throws -> [CreditNoteModel] {
        guard let companyId = SessionManager.shared.selectedCompanyId else {
            throw URLError(.badURL)
        }
        var items = [URLQueryItem(name: "company_id", value: String(companyId))]
        // Searching and filtering belong to the server: this screen holds a page, so a
        // search done here missed every credit note that had not been downloaded.
        if let search, !search.isEmpty { items.append(URLQueryItem(name: "search", value: search)) }
        if let type, !type.isEmpty { items.append(URLQueryItem(name: "type", value: type)) }
        if limit > 0 {
            items.append(URLQueryItem(name: "limit", value: String(limit)))
            items.append(URLQueryItem(name: "offset", value: String(offset)))
        }
        var components = URLComponents(string: "\(baseURL)/credit-notes")!
        components.queryItems = items
        let url = components.url!
        var req = URLRequest(url: url)
        req.httpMethod = "GET"

        if let token = KeychainManager.shared.loadToken() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: req)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode([CreditNoteModel].self, from: data)
    }
    
    // MARK: - Get Credit Note By ID
    func fetchByID(id: Int) async throws -> CreditNoteDetailModel {
        guard let companyId = SessionManager.shared.selectedCompanyId else {
            throw URLError(.badURL)
        }
        let url = URL(string: "\(baseURL)/credit-notes/\(id)?company_id=\(companyId)")!
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        
        if let token = KeychainManager.shared.loadToken() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: req)
        
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        return try JSONDecoder().decode(CreditNoteDetailModel.self, from: data)
    }
    
    // MARK: - Create Credit Note
    func create(dto: CreateCreditNoteRequestDTO) async throws {
        let url = URL(string: "\(baseURL)/credit-notes")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = KeychainManager.shared.loadToken() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        req.httpBody = try JSONEncoder().encode(dto)
        
        let (_, response) = try await URLSession.shared.data(for: req)
        
        guard let http = response as? HTTPURLResponse, http.statusCode == 201 else {
            throw URLError(.badServerResponse)
        }
    }

    /// Counts and amounts over every credit note that matches, not the loaded page.
    func fetchSummary(search: String? = nil) async throws -> CreditNoteSummaryModel {
        guard let companyId = SessionManager.shared.selectedCompanyId else {
            throw URLError(.badURL)
        }
        var components = URLComponents(string: "\(baseURL)/credit-notes/summary")!
        components.queryItems = [URLQueryItem(name: "company_id", value: String(companyId))]
        if let search, !search.isEmpty {
            components.queryItems?.append(URLQueryItem(name: "search", value: search))
        }
        guard let url = components.url else { throw URLError(.badURL) }

        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        if let token = KeychainManager.shared.loadToken() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(CreditNoteSummaryModel.self, from: data)
    }
}

/// The figures above the credit-note list, from the server.
struct CreditNoteSummaryModel: Codable {
    let total: Int
    let returns: Int
    let adjustments: Int
    let discounts: Int
    let amount: Double
    let balance: Double

    static let empty = CreditNoteSummaryModel(
        total: 0, returns: 0, adjustments: 0, discounts: 0, amount: 0, balance: 0
    )
}

// MARK: - Spending a credit note

extension CreditNoteService {

    /// Puts a credit note's balance against one of the customer's unpaid invoices.
    ///
    /// `amount` of nil applies as much as the invoice can take, which is what somebody
    /// means by "apply this to that".
    @discardableResult
    func applyToInvoice(
        creditNoteID: Int,
        invoiceID: Int,
        amount: Double? = nil
    ) async throws -> Double {
        guard let companyID = SessionManager.shared.selectedCompanyId else {
            throw CreditNoteActionError(message: "Select a company first.")
        }

        var body: [String: Any] = ["invoice_id": invoiceID]
        if let amount { body["amount"] = amount }

        let data = try await post(
            path: "/credit-notes/\(creditNoteID)/apply",
            companyID: companyID,
            body: body
        )

        struct Reply: Decodable { let applied: Double }
        return (try? JSONDecoder().decode(Reply.self, from: data))?.applied ?? 0
    }

    /// Hands the money back. The server reduces the credit note and writes the ledger
    /// entry; this only has to say how much and how.
    func refund(
        creditNoteID: Int,
        clientID: Int,
        amount: Double,
        method: String,
        reference: String
    ) async throws {
        guard let companyID = SessionManager.shared.selectedCompanyId else {
            throw CreditNoteActionError(message: "Select a company first.")
        }

        _ = try await post(path: "/refunds", companyID: companyID, body: [
            "client_id": clientID,
            "credit_note_id": creditNoteID,
            "amount": amount,
            "method": method,
            "reference": reference,
        ])
    }

    /// The customer's invoices that still owe something, for choosing one to put the
    /// credit against.
    func unpaidInvoices(clientID: Int) async throws -> [InvoiceSummaryModel] {
        guard let companyID = SessionManager.shared.selectedCompanyId else {
            throw CreditNoteActionError(message: "Select a company first.")
        }
        return try await InvoiceService().fetchUnpaidInvoices(
            clientID: clientID, companyID: companyID
        )
    }

    private func post(path: String, companyID: Int, body: [String: Any]) async throws -> Data {
        guard let url = URL(string: "\(AppEnvironment.baseURL)\(path)?company_id=\(companyID)") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(String(companyID), forHTTPHeaderField: "X-Company-ID")
        if let token = KeychainManager.shared.loadToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200...299).contains(http.statusCode) else {
            // The server's own sentence where there is one: "That's more than the
            // credit note has left" tells somebody what to do next.
            struct ErrorBody: Decodable { let error: String }
            if let parsed = try? JSONDecoder().decode(ErrorBody.self, from: data),
               !parsed.error.isEmpty {
                throw CreditNoteActionError(message: parsed.error)
            }
            throw CreditNoteActionError(message: "That didn't work. Try again.")
        }
        return data
    }
}

struct CreditNoteActionError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
