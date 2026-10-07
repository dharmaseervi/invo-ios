//
//  clientServices.swift
//  invo
//
//  Created by dharmaseervi on 11/19/25.
//

import Foundation
import Combine

class ClientServices: ObservableObject {
    init (){}
    
    @Published var clients: [ClientModel] = []
    private let baseURL = AppEnvironment.baseURL
    
    func CreateClient(clientPayload: CreateClientRequest) async throws {
        guard let url = URL(string: "\(baseURL)/clients") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        
        if let token = KeychainManager.shared.loadToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(clientPayload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200...299).contains(http.statusCode) else {
            let error = try? JSONDecoder().decode(AuthErrorResponse.self, from: data)
            throw error ?? AuthErrorResponse(error: "Failed to create client")
        }
    }
    
    
    // MARK: - GET Clients for company
    /// One page of a company's customers.
    ///
    /// `limit` of 0 asks for every one, which is what this used to do on every visit —
    /// a shop with a few thousand customers downloaded the lot to show the first screen.
    /// Searching belongs to the server for the same reason: a search done here only ever
    /// matched the customers that happened to be loaded.
    func loadClients(
        for companyId: Int,
        search: String? = nil,
        limit: Int = 0,
        offset: Int = 0
    ) async throws -> [ClientModel] {
        var components = URLComponents(string: "\(baseURL)/companies/\(companyId)/clients")
        var items: [URLQueryItem] = []
        if let search, !search.isEmpty {
            items.append(URLQueryItem(name: "search", value: search))
        }
        if limit > 0 {
            items.append(URLQueryItem(name: "limit", value: String(limit)))
            items.append(URLQueryItem(name: "offset", value: String(offset)))
        }
        components?.queryItems = items.isEmpty ? nil : items

        guard let url = components?.url else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)

        if let token = KeychainManager.shared.loadToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200...299).contains(http.statusCode) else {
            let error = try? JSONDecoder().decode(AuthErrorResponse.self, from: data)
            throw error ?? AuthErrorResponse(error: "Failed to load clients")
        }

        let decoded = try JSONDecoder().decode([String: [ClientModel]].self, from: data)
        return decoded["clients"] ?? []
    }

    /// The company's Cash or UPI account, created on first use.
    ///
    /// Asked of the server by name. Finding it by downloading every customer and looking
    /// through them is what stopped the client list being paged at all — the account
    /// might be on page four — and two tills asking at once each made their own.
    func quickSaleClient(companyId: Int, account: QuickSaleAccount) async throws -> ClientModel {
        guard let url = URL(string: "\(baseURL)/companies/\(companyId)/quick-sale-client") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = KeychainManager.shared.loadToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(["account": account.rawValue])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200...299).contains(http.statusCode) else {
            let error = try? JSONDecoder().decode(AuthErrorResponse.self, from: data)
            throw error ?? AuthErrorResponse(error: "Failed to set up that account")
        }
        return try JSONDecoder().decode(ClientModel.self, from: data)
    }
    
    

    
}
