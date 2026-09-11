//
//  InvoiceService.swift
//  invo
//
//  Created by dharmaseervi on 11/28/25.
//

import Foundation

struct OversellItem: Codable {
    let name: String
    let available: Int
    let requested: Int
}

private struct OversellResponse: Codable {
    let items: [OversellItem]
}

struct OversellError: Error {
    let items: [OversellItem]
}

final class InvoiceService {

    private let baseURL = AppEnvironment.baseURL

    // MARK: - Create Invoice
    func createInvoices(payload: InvoiceRequestDTO) async throws
        -> CreateInvoiceResponse
    {

        guard let url = URL(string: "\(baseURL)/invoices") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)

        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Auth
        if let token = KeychainManager.shared.loadToken() {
            request.setValue(
                "Bearer \(token)",
                forHTTPHeaderField: "Authorization"
            )
        }

        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        switch http.statusCode {
        case 200, 201:
            return try JSONDecoder()
                .decode(CreateInvoiceResponse.self, from: data)
        case 400:
            throw NSError(
                domain: "Invoice",
                code: 400,
                userInfo: [
                    NSLocalizedDescriptionKey: "Invalid invoice data"
                ]
            )
        case 401:
            throw NSError(
                domain: "Invoice",
                code: 401,
                userInfo: [
                    NSLocalizedDescriptionKey: "Unauthorized"
                ]
            )
        default:
            throw NSError(
                domain: "Invoice",
                code: http.statusCode,
                userInfo: [
                    NSLocalizedDescriptionKey: "Failed to create invoice"
                ]
            )
        }
    }

    // MARK: - Get All Invoices
    func getInvoices(
        companyID: Int? = nil,
        clientID: Int? = nil,
        limit: Int = 10,
        offset: Int = 0
    ) async throws -> InvoiceListResponse {

        var urlComponents = URLComponents(string: "\(baseURL)/invoices")
        urlComponents?.queryItems = []

        if let companyID = companyID {
            urlComponents?.queryItems?.append(
                URLQueryItem(name: "company_id", value: String(companyID))
            )
        }

        if let clientID = clientID {
            urlComponents?.queryItems?.append(
                URLQueryItem(name: "client_id", value: String(clientID))
            )
        }

        urlComponents?.queryItems?.append(
            URLQueryItem(name: "limit", value: String(limit))
        )
        urlComponents?.queryItems?.append(
            URLQueryItem(name: "offset", value: String(offset))
        )

        guard let url = urlComponents?.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Auth
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

        switch http.statusCode {
        case 200:
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let invoices = try decoder.decode(
                InvoiceListResponse.self,
                from: data
            )
            return invoices

        case 401:
            throw NSError(
                domain: "Invoice",
                code: 401,
                userInfo: [
                    NSLocalizedDescriptionKey: "Unauthorized"
                ]
            )
        case 404:
            return InvoiceListResponse(data: [], limit: limit, offset: offset)
        default:
            throw NSError(
                domain: "Invoice",
                code: http.statusCode,
                userInfo: [
                    NSLocalizedDescriptionKey: "Failed to fetch invoices"
                ]
            )
        }
    }

    // MARK: - Get Single Invoice by ID
    // MARK: - Get Single Invoice by ID
    func getInvoiceByID(_ invoiceID: Int) async throws -> InvoiceDetailResponse
    {

        guard let url = URL(string: "\(baseURL)/invoices/\(invoiceID)") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

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

        switch http.statusCode {
        case 200:
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(InvoiceDetailResponse.self, from: data)

        case 401:
            throw NSError(
                domain: "Invoice",
                code: 401,
                userInfo: [
                    NSLocalizedDescriptionKey: "Unauthorized"
                ]
            )
        case 404:
            throw NSError(
                domain: "Invoice",
                code: 404,
                userInfo: [
                    NSLocalizedDescriptionKey: "Invoice not found"
                ]
            )
        default:
            throw NSError(
                domain: "Invoice",
                code: http.statusCode,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "Failed to fetch invoice: \(http.statusCode)"
                ]
            )
        }
    }  // MARK: - Response Models (from API)

    func getInvoiceNumberPreview(companyID: Int) async throws -> String {

        guard
            let url = URL(
                string:
                    "\(baseURL)/invoices/number-preview?company_id=\(companyID)"
            )
        else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

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

        struct PreviewResponse: Codable {
            let preview: String
        }

        return try JSONDecoder()
            .decode(PreviewResponse.self, from: data)
            .preview
    }

    func fetchUnpaidInvoices(clientID: Int, companyID: Int) async throws
        -> [InvoiceSummaryModel]
    {
        let url = URL(
            string:
                "\(AppEnvironment.baseURL)/clients/\(clientID)/unpaid-invoices"
        )!

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(
            String(companyID),
            forHTTPHeaderField: "X-Company-ID"
        )
        if let token = KeychainManager.shared.loadToken() {
            request.setValue(
                "Bearer \(token)",
                forHTTPHeaderField: "Authorization"
            )
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let decoded = try decoder.decode(
            InvoiceSummaryResponse.self,
            from: data
        )
        
        return decoded.data
        
    }
    
    func fetchInvoicesByClient(
        clientID: Int,
        companyID: Int
    ) async throws -> InvoiceListResponse {
        
        guard let url = URL(
            string: "\(baseURL)/clients/\(clientID)/invoices"
        ) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // Auth
        if let token = KeychainManager.shared.loadToken() {
            request.setValue(
                "Bearer \(token)",
                forHTTPHeaderField: "Authorization"
            )
        }
        
        // Company context
        request.setValue(
            String(companyID),
            forHTTPHeaderField: "X-Company-ID"
        )
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let http = response as? HTTPURLResponse,
              http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try decoder.decode(
            InvoiceListResponse.self,
            from: data
        )
    }

    
    // MARK: - Issue Invoice
    func issueInvoice(invoiceID: Int, force: Bool = false) async throws {
        let urlString = "\(baseURL)/invoices/\(invoiceID)/issue" + (force ? "?force=true" : "")
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = KeychainManager.shared.loadToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        if http.statusCode == 409,
           let decoded = try? JSONDecoder().decode(OversellResponse.self, from: data) {
            throw OversellError(items: decoded.items)
        }

        if http.statusCode != 200 {
            throw NSError(
                domain: "Invoice",
                code: http.statusCode,
                userInfo: [
                    NSLocalizedDescriptionKey: "Failed to issue invoice"
                ]
            )
        }
    }
    
    
    // MARK: - Update Invoice (Draft Only)
    func updateInvoice(invoiceID: Int, payload: UpdateInvoiceRequestDTO) async throws {
        guard let url = URL(string: "\(baseURL)/invoices/\(invoiceID)/update") else {
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
        
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        switch http.statusCode {
        case 200, 204:
            return // Success
        case 400:
            // Try to parse error message
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NSError(
                    domain: "Invoice",
                    code: 400,
                    userInfo: [
                        NSLocalizedDescriptionKey: errorResponse.message
                    ]
                )
            }
            throw NSError(
                domain: "Invoice",
                code: 400,
                userInfo: [
                    NSLocalizedDescriptionKey: "Invalid invoice data"
                ]
            )
        case 401:
            throw NSError(
                domain: "Invoice",
                code: 401,
                userInfo: [
                    NSLocalizedDescriptionKey: "Unauthorized"
                ]
            )
        case 403:
            throw NSError(
                domain: "Invoice",
                code: 403,
                userInfo: [
                    NSLocalizedDescriptionKey: "Only draft invoices can be edited"
                ]
            )
        case 404:
            throw NSError(
                domain: "Invoice",
                code: 404,
                userInfo: [
                    NSLocalizedDescriptionKey: "Invoice not found"
                ]
            )
        default:
            throw NSError(
                domain: "Invoice",
                code: http.statusCode,
                userInfo: [
                    NSLocalizedDescriptionKey: "Failed to update invoice"
                ]
            )
        }
    }
    
    // MARK: - Delete Invoice (Draft Only)
    func deleteInvoice(invoiceID: Int) async throws {
        guard let url = URL(string: "\(baseURL)/invoices/\(invoiceID)") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
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
        
        switch http.statusCode {
        case 200, 204:
            return // Success
        case 401:
            throw NSError(
                domain: "Invoice",
                code: 401,
                userInfo: [
                    NSLocalizedDescriptionKey: "Unauthorized"
                ]
            )
        case 403:
            throw NSError(
                domain: "Invoice",
                code: 403,
                userInfo: [
                    NSLocalizedDescriptionKey: "Only draft invoices can be deleted"
                ]
            )
        case 404:
            throw NSError(
                domain: "Invoice",
                code: 404,
                userInfo: [
                    NSLocalizedDescriptionKey: "Invoice not found"
                ]
            )
        default:
            // The API reports failures as {"error": "..."} — read that first so the real
            // reason (e.g. the invoice has payments against it) reaches the user instead
            // of a generic message.
            if let payload = try? JSONDecoder().decode([String: String].self, from: data),
               let reason = payload["error"], !reason.isEmpty {
                throw NSError(
                    domain: "Invoice",
                    code: http.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: reason]
                )
            }
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NSError(
                    domain: "Invoice",
                    code: http.statusCode,
                    userInfo: [
                        NSLocalizedDescriptionKey: errorResponse.message
                    ]
                )
            }
            throw NSError(
                domain: "Invoice",
                code: http.statusCode,
                userInfo: [
                    NSLocalizedDescriptionKey: "Failed to delete invoice"
                ]
            )
        }
    }


}


// MARK: - Error Response Model
struct ErrorResponse: Codable {
    let message: String
    let error: String?
}
