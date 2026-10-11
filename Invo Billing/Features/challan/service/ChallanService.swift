import Foundation

private struct APIError: Decodable { let error: String? }
private struct ChallanServiceError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
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
        let (data, response) = try await URLSession.shared.data(for: req)
        try check(data, response)
        return try JSONDecoder().decode(CreateChallanResponse.self, from: data)
    }

    func listChallans(companyID: Int) async throws -> [ChallanResponse] {
        guard var components = URLComponents(string: "\(baseURL)/challans") else { throw URLError(.badURL) }
        components.queryItems = [URLQueryItem(name: "company_id", value: "\(companyID)")]
        guard let url = components.url else { throw URLError(.badURL) }
        let req = authorizedRequest(url: url, method: "GET")
        let (data, response) = try await URLSession.shared.data(for: req)
        try check(data, response)
        struct Wrapper: Decodable { let challans: [ChallanResponse] }
        return try JSONDecoder().decode(Wrapper.self, from: data).challans
    }

    func getChallanByID(_ id: Int) async throws -> ChallanDetailResponse {
        guard let url = URL(string: "\(baseURL)/challans/\(id)") else { throw URLError(.badURL) }
        let req = authorizedRequest(url: url, method: "GET")
        let (data, response) = try await URLSession.shared.data(for: req)
        try check(data, response)
        return try JSONDecoder().decode(ChallanDetailResponse.self, from: data)
    }

    func dispatchChallan(_ id: Int) async throws {
        guard let url = URL(string: "\(baseURL)/challans/\(id)/dispatch") else { throw URLError(.badURL) }
        let req = authorizedRequest(url: url, method: "PATCH")
        let (data, response) = try await URLSession.shared.data(for: req)
        try check(data, response)
    }
}
