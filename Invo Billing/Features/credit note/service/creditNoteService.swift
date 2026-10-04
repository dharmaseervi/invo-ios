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
