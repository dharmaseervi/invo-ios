//
//  PurchaseService.swift
//  Invo Billing
//

import Foundation

struct PurchasesService {

    private let baseURL = AppEnvironment.baseURL

    // MARK: - Suppliers

    func suppliers(
        companyID: Int, search: String? = nil, limit: Int? = nil, offset: Int = 0
    ) async throws -> SuppliersResponse {
        var items = [URLQueryItem(name: "company_id", value: String(companyID))]
        if let search, !search.isEmpty {
            items.append(URLQueryItem(name: "search", value: search))
        }
        if let limit, limit > 0 {
            items.append(URLQueryItem(name: "limit", value: String(limit)))
            items.append(URLQueryItem(name: "offset", value: String(offset)))
        }
        return try await get("/suppliers", items)
    }

    func addSupplier(companyID: Int, request: NewSupplierRequest) async throws {
        _ = try await post("/suppliers", companyID: companyID, body: request) as EmptyReply
    }

    func updateSupplier(companyID: Int, supplierID: Int, request: UpdateSupplierRequest) async throws {
        try await put("/suppliers/\(supplierID)", companyID: companyID, body: request)
    }

    func cancelBill(companyID: Int, billID: Int) async throws {
        try await postNoBody("/purchase-bills/\(billID)/cancel", companyID: companyID)
    }

    func supplierStatementPDF(
        companyID: Int, supplierID: Int, start: String, end: String
    ) async throws -> Data {
        let queryItems = [
            URLQueryItem(name: "company_id", value: String(companyID)),
            URLQueryItem(name: "start", value: start),
            URLQueryItem(name: "end", value: end),
        ]
        var components = URLComponents(string: "\(baseURL)/suppliers/\(supplierID)/ledger/statement.pdf")
        components?.queryItems = queryItems
        guard let url = components?.url else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        if let token = KeychainManager.shared.loadToken() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            struct ErrorBody: Decodable { let error: String }
            if let body = try? JSONDecoder().decode(ErrorBody.self, from: data) {
                throw PurchaseError(message: body.error)
            }
            throw PurchaseError(message: "Couldn't generate that statement.")
        }
        return data
    }

    // MARK: - Bills

    /// status: unpaid, partial, paid, owed, overdue — or nil for everything.
    func bills(companyID: Int, supplierID: Int? = nil, status: String? = nil, search: String? = nil, limit: Int = 50, offset: Int = 0) async throws -> [PurchaseBill] {
        var items = [URLQueryItem(name: "company_id", value: String(companyID))]
        if let supplierID {
            items.append(URLQueryItem(name: "supplier_id", value: String(supplierID)))
        }
        if let status, !status.isEmpty {
            items.append(URLQueryItem(name: "status", value: status))
        }
        items.append(URLQueryItem(name: "limit", value: String(limit)))
        items.append(URLQueryItem(name: "offset", value: String(offset)))
        if let search, !search.isEmpty {
            items.append(URLQueryItem(name: "search", value: search))
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

    // MARK: - Returns

    func returns(companyID: Int, supplierID: Int? = nil) async throws -> [PurchaseReturn] {
        var items = [URLQueryItem(name: "company_id", value: String(companyID))]
        if let supplierID {
            items.append(URLQueryItem(name: "supplier_id", value: String(supplierID)))
        }
        let response: PurchaseReturnsResponse = try await get("/purchase-returns", items)
        return response.data
    }

    func recordReturn(companyID: Int, request: NewPurchaseReturnRequest) async throws {
        _ = try await post("/purchase-returns", companyID: companyID, body: request) as EmptyReply
    }

    /// What a bill contained, for choosing what to send back from it.
    func billDetail(companyID: Int, billID: Int) async throws -> PurchaseBillDetail {
        try await bill(companyID: companyID, billID: billID)
    }

    // MARK: - Statements

    /// A supplier's statement: their bills, the payments made to them, and the running
    /// balance. The summary comes back with the lines, so the figure at the top and the
    /// entries under it are always the same read.
    func ledger(
        companyID: Int,
        supplierID: Int,
        limit: Int? = nil,
        offset: Int = 0
    ) async throws -> SupplierLedgerResponse {
        var items = [URLQueryItem(name: "company_id", value: String(companyID))]
        if let limit {
            items.append(URLQueryItem(name: "limit", value: String(limit)))
            items.append(URLQueryItem(name: "offset", value: String(offset)))
        }
        return try await get("/suppliers/\(supplierID)/ledger", items)
    }

    // MARK: - Plumbing

    private func put<Body: Encodable>(_ path: String, companyID: Int, body: Body) async throws {
        var components = URLComponents(string: "\(baseURL)\(path)")
        components?.queryItems = [URLQueryItem(name: "company_id", value: String(companyID))]
        guard let url = components?.url else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = KeychainManager.shared.loadToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await URLSession.shared.data(for: request)
        try check(response, data)
    }

    private func postNoBody(_ path: String, companyID: Int) async throws {
        var components = URLComponents(string: "\(baseURL)\(path)")
        components?.queryItems = [URLQueryItem(name: "company_id", value: String(companyID))]
        guard let url = components?.url else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        if let token = KeychainManager.shared.loadToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        try check(response, data)
    }

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
