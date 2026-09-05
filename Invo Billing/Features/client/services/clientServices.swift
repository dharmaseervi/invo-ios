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
    func loadClients(for companyId: Int) async throws -> [ClientModel] {
        guard let url = URL(string: "\(baseURL)/companies/\(companyId)/clients") else {
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
    
    

    
}
