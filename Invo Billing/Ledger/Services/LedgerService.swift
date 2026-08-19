import Foundation

final class LedgerService {

    static let shared = LedgerService()
    private init() {}

    private let baseURL = AppEnvironment.baseURL

    func fetchLedger(clientID: Int, companyID: Int) async throws
        -> [LedgerEntryModel]
    {

        guard
            let url = URL(
                string: "\(baseURL)/ledger/\(clientID)"
            )
        else {
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

    func fetchCompanyLedger(companyID: Int) async throws -> [LedgerEntryModel] {

        let url = URL(
            string: "\(AppEnvironment.baseURL)/companies/\(companyID)/ledger"
        )!

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        if let token = KeychainManager.shared.loadToken() {
            request.setValue(
                "Bearer \(token)",
                forHTTPHeaderField: "Authorization"
            )
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        print(String(data: data, encoding: .utf8)!)

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
