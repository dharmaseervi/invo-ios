//
//  itemService.swift
//  invo
//
//  Created by dharmaseervi on 11/23/25.
//

import Combine
import Foundation

struct ItemServiceError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

private struct APIErrorBody: Decodable {
    let error: String?
}

class ItemService {
    private let baseURL = AppEnvironment.baseURL

    init() {}

    /// Throws ItemServiceError with the server's own message when the response
    /// isn't one of `okStatuses` — e.g. a duplicate-SKU 409 becomes a real message
    /// instead of a generic "failed to save".
    private func decodeErrorIfNeeded(data: Data, response: URLResponse, okStatuses: Set<Int>) throws {
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard !okStatuses.contains(http.statusCode) else { return }

        if let body = try? JSONDecoder().decode(APIErrorBody.self, from: data), let message = body.error {
            throw ItemServiceError(message: message)
        }
        throw URLError(.badServerResponse)
    }

    func createItem(payload: ItemRequestDTO) async throws -> Bool {
        guard let url = URL(string: "\(baseURL)/items") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = KeychainManager.shared.loadToken() {
            request.setValue(
                "Bearer \(token)",
                forHTTPHeaderField: "Authorization"
            )
        }

        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        try decodeErrorIfNeeded(data: data, response: response, okStatuses: [201])
        return true
    }

    func updateItem(id: Int, payload: ItemRequestDTO) async throws -> Bool {
        guard let url = URL(string: "\(baseURL)/items/\(id)") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = KeychainManager.shared.loadToken() {
            request.setValue(
                "Bearer \(token)",
                forHTTPHeaderField: "Authorization"
            )
        }

        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        try decodeErrorIfNeeded(data: data, response: response, okStatuses: [200])
        return true
    }

    /// One page of items. `cursor` continues a previous page; `search` filters on the
    /// server so a catalogue of thousands never has to be downloaded to find one item.
    func loadItems(
        companyId: Int,
        limit: Int? = nil,
        cursor: String? = nil,
        search: String? = nil
    ) async throws -> ItemListResponse {

        guard var components = URLComponents(string: "\(baseURL)/items/\(companyId)/all") else {
            throw URLError(.badURL)
        }

        var query: [URLQueryItem] = []
        if let limit { query.append(URLQueryItem(name: "limit", value: String(limit))) }
        if let cursor, !cursor.isEmpty { query.append(URLQueryItem(name: "cursor", value: cursor)) }
        if let search, !search.isEmpty { query.append(URLQueryItem(name: "search", value: search)) }
        components.queryItems = query.isEmpty ? nil : query

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        if let token = KeychainManager.shared.loadToken() {
            request.setValue(
                "Bearer \(token)",
                forHTTPHeaderField: "Authorization"
            )
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        // A 401 has to be told apart from a server error: retrying a rejected token can
        // never succeed, so the screen needs to say "sign in again" rather than offering
        // a Try again button that is guaranteed to fail.
        if http.statusCode == 401 {
            throw SessionExpiredError()
        }
        guard http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(ItemListResponse.self, from: data)
    }
    
    func restockItem(id: Int, payload: RestockRequestDTO) async throws -> Bool {
        guard let url = URL(string: "\(baseURL)/item/\(id)/restock") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = KeychainManager.shared.loadToken() {
            request.setValue(
                "Bearer \(token)",
                forHTTPHeaderField: "Authorization"
            )
        }

        request.httpBody = try JSONEncoder().encode(payload)

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        return http.statusCode == 200
    }

    func getItemByID(_ id: Int) async throws -> [ItemResponse] {
        
        guard let url = URL(string: "\(baseURL)/item/\(id)/one") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        if let token = KeychainManager.shared.loadToken() {
            request.setValue(
                "Bearer \(token)",
                forHTTPHeaderField: "Authorization"
            )
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard http.statusCode == 200 else {
            throw NSError(
                domain: "ItemService",
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "Item not found"]
            )
        }
        
        let decoded = try JSONDecoder().decode(ItemListResponse.self, from: data)
        return decoded.items
    }
//

}

class CategoryService: ObservableObject {
    private let baseURL = AppEnvironment.baseURL
    @Published var categories: [CategoryModel] = []

    // MARK: - Categories
    func getCategories(companyId: Int) async throws -> [CategoryResponse] {
        guard
            let url = URL(
                string: "\(baseURL)/categories/\(companyId)"
            )
        else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        if let token = KeychainManager.shared.loadToken() {
            request.setValue(
                "Bearer \(token)",
                forHTTPHeaderField: "Authorization"
            )
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200
        else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(
            CategoryListResponse.self,
            from: data
        )

        DispatchQueue.main.async {
            self.categories = decoded.categories.map {
                CategoryModel(id: $0.id, name: $0.name)
            }
        }

        return decoded.categories
    }

    // POST create category
    func createCategory(
        name: String,
        companyId: Int,
        defaultHSNCode: String? = nil,
        defaultTaxRate: Double? = nil
    ) async throws {
        let url = URL(string: "\(baseURL)/categories")!

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = KeychainManager.shared.loadToken() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let payload = CategoryRequest(
            name: name,
            company_id: companyId,
            default_hsn_code: defaultHSNCode,
            default_tax_rate: defaultTaxRate
        )

        req.httpBody = try JSONEncoder().encode(payload)

        let (_, response) = try await URLSession.shared.data(for: req)

        guard let http = response as? HTTPURLResponse,
            (200..<300).contains(http.statusCode)
        else {
            throw URLError(.badServerResponse)
        }

    }

}
