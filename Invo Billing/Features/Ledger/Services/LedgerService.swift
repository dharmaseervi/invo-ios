import Foundation

final class LedgerService {

    static let shared = LedgerService()
    private init() {}

    private let baseURL = AppEnvironment.baseURL

    /// A customer's statement, oldest first. limit 0 asks for the whole history, which
    /// for a long-standing customer is thousands of lines fetched to show the last few;
    /// a page takes the newest `limit` entries and still reads forwards.
    func fetchLedger(clientID: Int, companyID: Int, limit: Int = 0, offset: Int = 0) async throws
        -> [LedgerEntryModel]
    {

        var path = "\(baseURL)/ledger/\(clientID)"
        if limit > 0 { path += "?limit=\(limit)&offset=\(offset)" }
        guard let url = URL(string: path) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        if let token = KeychainManager.shared.loadToken() {
            request.setValue(
                "Bearer \(token)",
                forHTTPHeaderField: "Authorization"
            )
        }
        
        request.setValue(
            String(companyID),
            forHTTPHeaderField: "X-Company-ID"
        )

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse,
            http.statusCode == 200
        else {
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let decoded = try decoder.decode(LedgerResponse.self, from: data)
        
        return decoded.data                                                                              
    }

    /// The whole company's ledger — every invoice and payment it has ever made — so a
    /// page is the difference between a screen that opens and one that waits.
    func fetchCompanyLedger(companyID: Int, limit: Int = 0, offset: Int = 0) async throws -> [LedgerEntryModel] {

        var path = "\(AppEnvironment.baseURL)/companies/\(companyID)/ledger"
        if limit > 0 { path += "?limit=\(limit)&offset=\(offset)" }
        let url = URL(string: path)!

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        if let token = KeychainManager.shared.loadToken() {
            request.setValue(
                "Bearer \(token)",
                forHTTPHeaderField: "Authorization"
            )
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse,
            http.statusCode == 200
        else {
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let decoded = try decoder.decode(LedgerResponse.self, from: data)

        return decoded.data
    }

    /// One customer's totals over their whole history.
    func fetchClientSummary(clientID: Int, companyID: Int) async throws -> LedgerSummaryModel {
        guard let url = URL(string: "\(baseURL)/ledger/\(clientID)/summary") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if let token = KeychainManager.shared.loadToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.setValue(String(companyID), forHTTPHeaderField: "X-Company-ID")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(LedgerSummaryModel.self, from: data)
    }

    /// One row per customer with ledger history — the ledger list, without fetching
    /// every entry the business has ever written to build it.
    func fetchCompanySummaries(
        companyID: Int,
        search: String? = nil,
        limit: Int = 0,
        offset: Int = 0
    ) async throws -> CompanyLedgerPage {
        var components = URLComponents(string: "\(baseURL)/companies/\(companyID)/ledger/summary")
        components?.queryItems = []
        if let search, !search.isEmpty {
            components?.queryItems?.append(URLQueryItem(name: "search", value: search))
        }
        if limit > 0 {
            components?.queryItems?.append(URLQueryItem(name: "limit", value: String(limit)))
            components?.queryItems?.append(URLQueryItem(name: "offset", value: String(offset)))
        }
        guard let url = components?.url else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if let token = KeychainManager.shared.loadToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        struct Wrapper: Codable {
            let data: [LedgerSummaryModel]
            let totals: CompanyLedgerTotals?
        }
        let decoded = try JSONDecoder().decode(Wrapper.self, from: data)
        return CompanyLedgerPage(rows: decoded.data, totals: decoded.totals)
    }
}
