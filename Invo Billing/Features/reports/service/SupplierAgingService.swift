import Foundation

final class SupplierAgingService {
    private let baseURL = AppEnvironment.baseURL

    func fetchReport(companyID: Int) async throws -> SupplierAgingReport {
        guard let url = URL(string: "\(baseURL)/companies/\(companyID)/reports/supplier-aging") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = KeychainManager.shared.loadToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(SupplierAgingReport.self, from: data)
    }
}
