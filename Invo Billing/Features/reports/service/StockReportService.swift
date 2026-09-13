import Foundation

struct StockReportError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

private struct APIErrorBody: Decodable {
    let error: String?
}

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

        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        // Every failure used to collapse into URLError(.badServerResponse), so a 500, an
        // expired token and a dropped connection were indistinguishable both to the user
        // and in a bug report. Each gets its own outcome now.
        switch http.statusCode {
        case 200...299:
            break
        case 401, 403:
            throw SessionExpiredError()
        default:
            let serverMessage = (try? JSONDecoder().decode(APIErrorBody.self, from: data))?.error
            throw StockReportError(
                message: serverMessage ?? "The server couldn't produce the stock report (\(http.statusCode))."
            )
        }

        do {
            return try JSONDecoder().decode(StockReportResponse.self, from: data)
        } catch {
            throw StockReportError(message: "The stock report came back in a form the app didn't understand.")
        }
    }
}
