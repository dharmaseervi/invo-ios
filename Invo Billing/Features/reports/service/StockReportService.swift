import Foundation

final class StockReportService {

    private let baseURL = AppEnvironment.baseURL

    func fetchStockReport(companyID: Int) async throws -> StockReportResponse {
        guard let url = URL(string: "\(baseURL)/companies/\(companyID)/reports/stock") else {
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

        return try JSONDecoder().decode(StockReportResponse.self, from: data)
    }
}
