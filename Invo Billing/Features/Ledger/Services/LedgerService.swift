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

}
