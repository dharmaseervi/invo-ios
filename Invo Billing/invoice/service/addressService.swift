//
//  addressService.swift
//  Invo Billing
//
//  Created by dharmaseervi on 12/21/25.
//

import Foundation

final class AddressService {
    
    private let baseURL = AppEnvironment.baseURL
    
    // GET single address
    func getClientAddress(
        clientID: Int,
        type: String
    ) async throws -> AddressModel? {
        
        guard let url = URL(
            string: "\(baseURL)/clients/\(clientID)/address?type=\(type)"
        ) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        if let token = KeychainManager.shared.loadToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
       
        print(String(data: data, encoding: .utf8)!)

        
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard http.statusCode == 200 else {
            return nil
        }
        
        let decoded = try JSONDecoder().decode(AddressResponse.self, from: data)
        return decoded.data
    }

    
    // SAVE address
    func saveClientAddress(
        clientID: Int,
        payload: ClientAddressRequestDTO
    ) async throws {
        
        let url = URL(string: "\(baseURL)/clients/\(clientID)/address")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = KeychainManager.shared.loadToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        request.httpBody = try JSONEncoder().encode(payload)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw NSError(domain: "Address", code: 500)
        }
    }
}
