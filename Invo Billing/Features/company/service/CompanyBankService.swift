//
//  CompanyBankService.swift
//  Invo Billing
//
//  Created by dharmaseervi on 2/18/26.
//

import Foundation
import Combine

class CompanyBankService: ObservableObject {
    
    @Published var errorMessage: String?
    
    private let baseURL = AppEnvironment.baseURL
    
    init() {}
    
    // MARK: - Get Company Banks

    func getCompanyBanks(companyId: Int) async throws -> [CompanyBankResponse] {
        
        guard let url = URL(string: "\(baseURL)/companies/\(companyId)/banks") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        if let token = KeychainManager.shared.loadToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            throw URLError(.userAuthenticationRequired)
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if http.statusCode == 200 {
            // ✅ Decode as an Array: [CompanyBankResponse].self
            return try JSONDecoder().decode([CompanyBankResponse].self, from: data)
            
        } else if http.statusCode == 404 {
            // Return an empty array if not found
            return []
        } else {
            throw URLError(.badServerResponse)
        }
    }
    
    // MARK: - Create Bank
    func createBank(companyId: Int, payload: CompanyBankRequestDTO) async throws -> Bool {
        
        guard let url = URL(string: "\(baseURL)/companies/\(companyId)/banks") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Attach Bearer token
        if let token = KeychainManager.shared.loadToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            throw URLError(.userAuthenticationRequired)
        }
        
        request.httpBody = try JSONEncoder().encode(payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if http.statusCode == 200 || http.statusCode == 201 {
            return true
        } else {
            throw failure(data, status: http.statusCode)
        }
    }
    
    // MARK: - Update Bank
    func updateBank(companyId: Int, bankId: Int, payload: CompanyBankRequestDTO) async throws -> Bool {
        
        guard let url = URL(string: "\(baseURL)/companies/\(companyId)/banks/\(bankId)") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = KeychainManager.shared.loadToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            throw URLError(.userAuthenticationRequired)
        }
        
        request.httpBody = try JSONEncoder().encode(payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if http.statusCode == 200 {
            return true
        } else {
            throw failure(data, status: http.statusCode)
        }
    }
    
    // MARK: - Delete Bank
    func deleteBank(companyId: Int, bankId: Int, password: String) async throws -> Bool {
        
        guard let url = URL(string: "\(baseURL)/companies/\(companyId)/banks/\(bankId)") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["password": password])
        
        if let token = KeychainManager.shared.loadToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            throw URLError(.userAuthenticationRequired)
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard http.statusCode == 204 || http.statusCode == 200 else {
            throw failure(data, status: http.statusCode)
        }
        return true
    }
    
    // MARK: - Set Default Bank
    func setDefaultBank(companyId: Int, bankId: Int) async throws -> Bool {
        
        guard let url = URL(string: "\(baseURL)/companies/\(companyId)/banks/\(bankId)/default") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        
        if let token = KeychainManager.shared.loadToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            throw URLError(.userAuthenticationRequired)
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard http.statusCode == 200 else { throw failure(data, status: http.statusCode) }
        return true
    }
    private func failure(_ data: Data, status: Int) -> NSError {
        struct APIError: Decodable { let error: String }
        let message = (try? JSONDecoder().decode(APIError.self, from: data))?.error
            ?? "Couldn't update the bank account. Please try again."
        return NSError(domain: "CompanyBankService", code: status,
                       userInfo: [NSLocalizedDescriptionKey: message])
    }

}
