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
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard response is HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
    }
    
    
    // MARK: - GET Clients for company
    func loadClients(for companyId: Int) async throws -> [ClientModel] {
        let url = URL(string: "\(baseURL)/companies/\(companyId)/clients")!
        var request = URLRequest(url: url)
        print("📡 Loading clients URL:", url.absoluteString)
        
        if let token = KeychainManager.shared.loadToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            print("🔑 Token:", token.prefix(30))
        } else {
            print("❌ No token found!")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        print("📡 Status:", http.statusCode)
        print("📡 Body:", String(data: data, encoding: .utf8) ?? "nil")
        
        if http.statusCode == 200 {
            let decoded = try JSONDecoder().decode([String: [ClientModel]].self, from: data)
            return decoded["clients"] ?? []
        } else {
            throw URLError(.cannotParseResponse)
        }
    }
    
    

    
}
