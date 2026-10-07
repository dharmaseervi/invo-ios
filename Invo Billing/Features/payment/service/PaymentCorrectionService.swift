//
//  PaymentCorrectionService.swift
//  Invo Billing
//
//  Reading the payment history, putting a payment right, and giving money back.
//

import Foundation

struct PaymentCorrectionService {

    private let baseURL = AppEnvironment.baseURL

    /// A company's payments, newest first.
    func history(companyID: Int, limit: Int = 50, offset: Int = 0) async throws -> [PaymentHistoryRow] {
        var components = URLComponents(string: "\(baseURL)/companies/\(companyID)/payments")
        components?.queryItems = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset)),
        ]
        guard let url = components?.url else { throw URLError(.badURL) }

        struct Wrapper: Decodable { let payments: [PaymentHistoryRow] }
        let wrapper: Wrapper = try await get(url)
        return wrapper.payments
    }

    /// Undoes a payment. The invoices it settled go back to owing.
    func reverse(companyID: Int, paymentID: Int, reason: String) async throws {
        try await send(
            path: "/payments/\(paymentID)/reverse",
            method: "POST",
            companyID: companyID,
            body: ["reason": reason]
        )
    }

    /// Moves a payment onto different invoices. An empty list leaves the whole payment
    /// on the customer's account.
    func reallocate(
        companyID: Int,
        paymentID: Int,
        allocations: [(invoiceID: Int, amount: Double)]
    ) async throws {
        try await send(
            path: "/payments/\(paymentID)/allocations",
            method: "PUT",
            companyID: companyID,
            body: ["allocations": allocations.map { ["invoice_id": $0.invoiceID, "amount": $0.amount] }]
        )
    }

    /// Records money handed back.
    func refund(companyID: Int, request: RefundRequestDTO) async throws {
        let data = try JSONEncoder().encode(request)
        guard let body = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw URLError(.badURL)
        }
        try await send(path: "/refunds", method: "POST", companyID: companyID, body: body)
    }

    // MARK: - Plumbing

    private func get<T: Decodable>(_ url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if let token = KeychainManager.shared.loadToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw PaymentActionError(message: message(from: response, data: data))
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func send(
        path: String,
        method: String,
        companyID: Int,
        body: [String: Any]
    ) async throws {
        var components = URLComponents(string: "\(baseURL)\(path)")
        components?.queryItems = [URLQueryItem(name: "company_id", value: String(companyID))]
        guard let url = components?.url else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = KeychainManager.shared.loadToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw PaymentActionError(message: message(from: response, data: data))
        }
    }

    /// The server's own sentence where there is one: "That's more than the credit note
    /// has left — 236.00" tells somebody what to do, and "something went wrong" does not.
    private func message(from response: URLResponse?, data: Data) -> String {
        struct ErrorBody: Decodable { let error: String }
        if let body = try? JSONDecoder().decode(ErrorBody.self, from: data), !body.error.isEmpty {
            return body.error
        }
        return "That didn't work. Try again."
    }
}

struct PaymentActionError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
