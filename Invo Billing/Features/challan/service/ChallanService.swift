import Foundation

private struct APIError: Decodable { let error: String? }
private struct ChallanServiceError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

struct ChallanPage: Decodable {
    let challans: [ChallanResponse]
    let has_more: Bool?
    let total: Int?
}

class ChallanService {
    private let baseURL = AppEnvironment.baseURL

    private func authorizedRequest(url: URL, method: String) -> URLRequest {
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = KeychainManager.shared.loadToken() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return req
    }

    private func check(_ data: Data, _ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200...299).contains(http.statusCode) else {
            let msg = (try? JSONDecoder().decode(APIError.self, from: data))?.error
                ?? "Server error \(http.statusCode)"
            throw ChallanServiceError(message: msg)
        }
    }

    func createChallan(payload: ChallanRequestDTO) async throws -> CreateChallanResponse {
        guard let url = URL(string: "\(baseURL)/challans") else { throw URLError(.badURL) }
        var req = authorizedRequest(url: url, method: "POST")
        req.httpBody = try JSONEncoder().encode(payload)
        let (data, response) = try await APIClient.shared.data(for: req)
        try check(data, response)
        return try JSONDecoder().decode(CreateChallanResponse.self, from: data)
    }

    func listChallans(companyID: Int, search: String = "", limit: Int = 40, offset: Int = 0) async throws -> ChallanPage {
        guard var components = URLComponents(string: "\(baseURL)/challans") else { throw URLError(.badURL) }
        components.queryItems = [
            URLQueryItem(name: "company_id", value: "\(companyID)"),
            URLQueryItem(name: "search", value: search),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)")
        ]
        guard let url = components.url else { throw URLError(.badURL) }
        let req = authorizedRequest(url: url, method: "GET")
        let (data, response) = try await APIClient.shared.data(for: req)
        try check(data, response)
        return try JSONDecoder().decode(ChallanPage.self, from: data)
    }

    func getChallanByID(_ id: Int) async throws -> ChallanDetailResponse {
        guard let url = URL(string: "\(baseURL)/challans/\(id)") else { throw URLError(.badURL) }
        let req = authorizedRequest(url: url, method: "GET")
        let (data, response) = try await APIClient.shared.data(for: req)
        try check(data, response)
        return try JSONDecoder().decode(ChallanDetailResponse.self, from: data)
    }

    func dispatchChallan(_ id: Int) async throws {
        guard let url = URL(string: "\(baseURL)/challans/\(id)/dispatch") else { throw URLError(.badURL) }
        let req = authorizedRequest(url: url, method: "PATCH")
        let (data, response) = try await APIClient.shared.data(for: req)
        try check(data, response)
    }
}
