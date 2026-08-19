//
//  company.swift
//  invo
//
//  Created by dharmaseervi on 11/17/25.
//

import Foundation
import Combine


class CompanyService: ObservableObject {
    
    @Published var errorMessage: String?
    @Published var company: [CompanyResponse]?
    private let baseURL = AppEnvironment.baseURL
    
    init() {}
    
    // MARK: - Create Company
    // Update createCompany to return the new company ID
    func createCompany(payload: CompanyRequestDTO) async throws -> Int? {
        guard let url = URL(string: "\(baseURL)/companies") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
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
        
        if http.statusCode == 201 {
            // Try to decode company ID from response
            if let decoded = try? JSONDecoder().decode(CreateCompanyResponse.self, from: data) {
                return decoded.company?.id ?? decoded.id
            }
            return nil
        } else {
            print("Create Company Error:", String(data: data, encoding: .utf8) ?? "")
            return nil
        }
    }
    
    // MARK: - Get My Company
    func getMyCompany() async throws -> [CompanyResponse]? {
        
        guard let url = URL(string: "\(baseURL)/companies") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        // Attach Bearer token
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
            let decoded = try JSONDecoder().decode(CompaniesResponse.self, from: data)
            return decoded.companies
        } else if http.statusCode == 404 {
            return nil  // company not created yet
        } else {
            print("Get Company Error:", String(data: data, encoding: .utf8) ?? "")
            return nil
        }
    }
}

