//
//  ExpenseService.swift
//  Invo Billing
//
//  Created by dharmaseervi on 12/19/25.
//

import Foundation

final class ExpenseService {
    
    private let baseURL = AppEnvironment.baseURL
    
    // MARK: - Create Expense
    func createExpense(payload: ExpenseCreatePayload) async throws -> Bool {
        
        guard let url = URL(string: "\(baseURL)/expenses") else {
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
    
    // MARK: - Get All Expenses
    func getExpenses(companyId: Int) async throws -> [Expense] {
        
        guard
            let url = URL(string: "\(baseURL)/companies/\(companyId)/expenses")
        else {
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
        
        let decoded = try JSONDecoder().decode(
            ExpenseListResponse.self,
            from: data
        )
        return decoded.expenses
    }
    
    // MARK: - Get Single Expense
    func getExpenseById(id: Int) async throws -> Expense {
        
        guard let url = URL(string: "\(baseURL)/expenses/\(id)") else {
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
        
        let decoded = try JSONDecoder().decode(
            ExpenseDetailResponse.self,
            from: data
        )
        return decoded.expense
    }
    
    // MARK: - Update Expense
    func updateExpense(
        id: Int,
        payload: ExpenseUpdatePayload
    ) async throws -> Bool {
        
        guard let url = URL(string: "\(baseURL)/expenses/\(id)") else {
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
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        return http.statusCode == 200
    }
    
    // MARK: - Delete Expense
    func deleteExpense(id: Int) async throws -> Bool {
        
        guard let url = URL(string: "\(baseURL)/expenses/\(id)") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        if let token = KeychainManager.shared.loadToken() {
            request.setValue(
                "Bearer \(token)",
                forHTTPHeaderField: "Authorization"
            )
        }
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        return http.statusCode == 200
    }
    
    // MARK: - Get Expenses by Date Range
    func getExpensesByDateRange(
        companyId: Int,
        startDate: String,
        endDate: String
    ) async throws -> [Expense] {
        
        let urlString = "\(baseURL)/companies/\(companyId)/expenses/range?start_date=\(startDate)&end_date=\(endDate)"
        guard let url = URL(string: urlString) else {
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
        
        let decoded = try JSONDecoder().decode(
            ExpenseListResponse.self,
            from: data
        )
        return decoded.expenses
    }
    
    // MARK: - Get Expense Statistics
    func getExpenseStats(companyId: Int) async throws -> ExpenseStatsResponse {
        
        guard
            let url = URL(string: "\(baseURL)/companies/\(companyId)/expenses/stats")
        else {
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
        
        let decoded = try JSONDecoder().decode(
            ExpenseStatsResponse.self,
            from: data
        )
        return decoded
    }
}
