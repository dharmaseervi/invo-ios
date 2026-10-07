//
//  ProfitLossService.swift
//  Invo Billing
//

import Foundation

final class ProfitLossService {

    private let baseURL = AppEnvironment.baseURL

    func fetch(companyID: Int, period: String) async throws -> ProfitLossResponse {
        var comps = URLComponents(string: "\(baseURL)/companies/\(companyID)/reports/profit-loss")!
        comps.queryItems = [URLQueryItem(name: "period", value: period)]
        guard let url = comps.url else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = KeychainManager.shared.loadToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(ProfitLossResponse.self, from: data)
    }
}
