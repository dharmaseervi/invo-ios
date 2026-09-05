import Foundation

final class GSTReportService {

    private let baseURL = AppEnvironment.baseURL

    func fetchGSTReport(companyID: Int, start: String, end: String) async throws -> GSTReportResponse {
        var components = URLComponents(string: "\(baseURL)/companies/\(companyID)/reports/gstr1")!
        components.queryItems = [
            URLQueryItem(name: "start", value: start),
            URLQueryItem(name: "end", value: end)
        ]

        guard let url = components.url else {
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

        return try JSONDecoder().decode(GSTReportResponse.self, from: data)
    }
}
