//
//  Untitled.swift
//  Invo Billing
//
//  Created by dharmaseervi on 2/2/26.
//

import Foundation

final class DashboardService {
    func fetchDashboard(period: String, companyId: Int) async throws
        -> DashboardResponse
    {
        
        var components = URLComponents(
            string: "\(AppEnvironment.baseURL)/dashboard"
        )!
        
        components.queryItems = [
            URLQueryItem(name: "period", value: period.lowercased()),
            URLQueryItem(name: "companyId", value: String(companyId))
        ]
        
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let token = KeychainManager.shared.loadToken() {
            request.setValue(
                "Bearer \(token)",
                forHTTPHeaderField: "Authorization"
            )
        }

        let (data, _) = try await URLSession.shared.data(for: request)

        return try JSONDecoder().decode(DashboardResponse.self, from: data)
    }
}
