//
//  PurchaseService.swift
//  Invo Billing
//

import Foundation

struct PurchasesService {

    private let baseURL = AppEnvironment.baseURL

    // MARK: - Suppliers

    func suppliers(companyID: Int, search: String? = nil) async throws -> SuppliersResponse {
        var items = [URLQueryItem(name: "company_id", value: String(companyID))]
        if let search, !search.isEmpty {
            items.append(URLQueryItem(name: "search", value: search))
        }
        return try await get("/suppliers", items)
    }

    func addSupplier(companyID: Int, request: NewSupplierRequest) async throws {
        _ = try await post("/suppliers", companyID: companyID, body: request) as EmptyReply
    }

    // MARK: - Bills

    /// status: unpaid, partial, paid, owed, overdue — or nil for everything.
    func bills(companyID: Int, supplierID: Int? = nil, status: String? = nil) async throws -> [PurchaseBill] {
        var items = [URLQueryItem(name: "company_id", value: String(companyID))]
        if let supplierID {
            items.append(URLQueryItem(name: "supplier_id", value: String(supplierID)))
        }
        if let status, !status.isEmpty {
            items.append(URLQueryItem(name: "status", value: status))
        }
        let response: PurchaseBillsResponse = try await get("/purchase-bills", items)
        return response.data
    }

    func bill(companyID: Int, billID: Int) async throws -> PurchaseBillDetail {
        try await get("/purchase-bills/\(billID)", [URLQueryItem(name: "company_id", value: String(companyID))])
    }

    func recordBill(companyID: Int, request: NewPurchaseBillRequest) async throws {
        _ = try await post("/purchase-bills", companyID: companyID, body: request) as EmptyReply
    }

    func paySupplier(companyID: Int, request: SupplierPaymentRequestDTO) async throws {
        _ = try await post("/supplier-payments", companyID: companyID, body: request) as EmptyReply
    }

    // MARK: - Plumbing

    private func get<T: Decodable>(_ path: String, _ query: [URLQueryItem]) async throws -> T {
        var components = URLComponents(string: "\(baseURL)\(path)")
        components?.queryItems = query
        guard let url = components?.url else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if let token = KeychainManager.shared.loadToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        try check(response, data)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func post<Body: Encodable, T: Decodable>(
        _ path: String, companyID: Int, body: Body
    ) async throws -> T {
        var components = URLComponents(string: "\(baseURL)\(path)")
        components?.queryItems = [URLQueryItem(name: "company_id", value: String(companyID))]
        guard let url = components?.url else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = KeychainManager.shared.loadToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try check(response, data)
        return try JSONDecoder().decode(T.self, from: data)
    }

    /// The server's own sentence where there is one — "That bill number is already
    /// recorded for this supplier" tells somebody what happened; a generic failure does
    /// not.
    private func check(_ response: URLResponse?, _ data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200...299).contains(http.statusCode) else {
            struct ErrorBody: Decodable { let error: String }
            if let body = try? JSONDecoder().decode(ErrorBody.self, from: data), !body.error.isEmpty {
                throw PurchaseError(message: body.error)
            }
            throw PurchaseError(message: "That didn't work. Try again.")
        }
    }
}

/// A reply whose body does not matter, only that it worked.
private struct EmptyReply: Decodable {
    init(from decoder: Decoder) throws {}
}

struct PurchaseError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
