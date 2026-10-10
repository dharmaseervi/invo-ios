import Foundation

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

    func createChallan(payload: ChallanRequestDTO) async throws -> CreateChallanResponse {
        guard let url = URL(string: "\(baseURL)/challans") else { throw URLError(.badURL) }
        var req = authorizedRequest(url: url, method: "POST")
        req.httpBody = try JSONEncoder().encode(payload)
        let (data, _) = try await URLSession.shared.data(for: req)
        return try JSONDecoder().decode(CreateChallanResponse.self, from: data)
    }

    func listChallans(companyID: Int) async throws -> [ChallanResponse] {
        guard var components = URLComponents(string: "\(baseURL)/challans") else { throw URLError(.badURL) }
        components.queryItems = [URLQueryItem(name: "company_id", value: "\(companyID)")]
        guard let url = components.url else { throw URLError(.badURL) }
        let req = authorizedRequest(url: url, method: "GET")
        let (data, _) = try await URLSession.shared.data(for: req)
        return try JSONDecoder().decode([ChallanResponse].self, from: data)
    }

    func getChallanByID(_ id: Int) async throws -> ChallanDetailResponse {
        guard let url = URL(string: "\(baseURL)/challans/\(id)") else { throw URLError(.badURL) }
        let req = authorizedRequest(url: url, method: "GET")
        let (data, _) = try await URLSession.shared.data(for: req)
        return try JSONDecoder().decode(ChallanDetailResponse.self, from: data)
    }

    func dispatchChallan(_ id: Int) async throws {
        guard let url = URL(string: "\(baseURL)/challans/\(id)/dispatch") else { throw URLError(.badURL) }
        let req = authorizedRequest(url: url, method: "PATCH")
        let (_, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}
