import Foundation

final class EstimateService {

    private let baseURL = AppEnvironment.baseURL

    private func authorizedRequest(url: URL, method: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = KeychainManager.shared.loadToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    func createEstimate(payload: EstimateRequestDTO) async throws -> CreateEstimateResponse {
        guard let url = URL(string: "\(baseURL)/estimates") else { throw URLError(.badURL) }
        var request = authorizedRequest(url: url, method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(CreateEstimateResponse.self, from: data)
    }

    func updateEstimate(id: Int, payload: UpdateEstimateRequestDTO) async throws {
        guard let url = URL(string: "\(baseURL)/estimates/\(id)/update") else { throw URLError(.badURL) }
        var request = authorizedRequest(url: url, method: "PUT")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    func getEstimates(companyID: Int?, clientID: Int? = nil) async throws -> [EstimateResponse] {
        var components = URLComponents(string: "\(baseURL)/estimates")!
        var query: [URLQueryItem] = []
        if let companyID { query.append(URLQueryItem(name: "company_id", value: String(companyID))) }
        if let clientID { query.append(URLQueryItem(name: "client_id", value: String(clientID))) }
        components.queryItems = query
        guard let url = components.url else { throw URLError(.badURL) }

        let request = authorizedRequest(url: url, method: "GET")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        struct Wrapper: Codable { let data: [EstimateResponse] }
        return try JSONDecoder().decode(Wrapper.self, from: data).data
    }

    func getEstimateByID(_ id: Int) async throws -> EstimateDetailResponse {
        guard let url = URL(string: "\(baseURL)/estimates/\(id)") else { throw URLError(.badURL) }
        let request = authorizedRequest(url: url, method: "GET")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(EstimateDetailResponse.self, from: data)
    }

    func updateStatus(id: Int, status: String) async throws {
        guard let url = URL(string: "\(baseURL)/estimates/\(id)/status") else { throw URLError(.badURL) }
        var request = authorizedRequest(url: url, method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(EstimateStatusUpdateDTO(status: status))

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    func convertToInvoice(id: Int) async throws -> ConvertEstimateResponse {
        guard let url = URL(string: "\(baseURL)/estimates/\(id)/convert") else { throw URLError(.badURL) }
        let request = authorizedRequest(url: url, method: "POST")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(ConvertEstimateResponse.self, from: data)
    }

    func downloadEstimatePDF(estimateID: Int, template: InvoiceTemplate = .classic) async throws -> URL {
        guard let url = URL(string: "\(baseURL)/estimates/\(estimateID)/pdf?template=\(template.rawValue)") else {
            throw URLError(.badURL)
        }
        let request = authorizedRequest(url: url, method: "GET")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Estimate_\(estimateID).pdf")
        try data.write(to: tempURL, options: .atomic)
        return tempURL
    }

    func getNumberPreview(companyID: Int) async throws -> String {
        guard let url = URL(string: "\(baseURL)/estimates/number-preview?company_id=\(companyID)") else {
            throw URLError(.badURL)
        }
        let request = authorizedRequest(url: url, method: "GET")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        struct Wrapper: Codable { let preview: String }
        return try JSONDecoder().decode(Wrapper.self, from: data).preview
    }
}
