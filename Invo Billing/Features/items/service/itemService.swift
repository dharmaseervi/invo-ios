//
//  itemService.swift
//  invo
//
//  Created by dharmaseervi on 11/23/25.
//

import Combine
import Foundation

class ItemService {
    private let baseURL = AppEnvironment.baseURL

    init() {}

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

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        return http.statusCode == 201
    }

    func loadItems(companyId: Int) async throws -> [ItemResponse] {

        guard let url = URL(string: "\(baseURL)/items/\(companyId)/all") else {
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
        guard let http = response as? HTTPURLResponse, http.statusCode == 200
        else {
            throw URLError(.badServerResponse)
        }

        let decode = try JSONDecoder().decode(ItemListResponse.self, from: data)
        
        return decode.items
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
    func createCategory(name: String, companyId: Int) async throws {
        let url = URL(string: "\(baseURL)/categories")!

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = KeychainManager.shared.loadToken() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let payload = CategoryRequest(name: name, company_id: companyId)

        req.httpBody = try JSONEncoder().encode(payload)

        let (_, response) = try await URLSession.shared.data(for: req)

        guard let http = response as? HTTPURLResponse,
            (200..<300).contains(http.statusCode)
        else {
            throw URLError(.badServerResponse)
        }

    }

}
