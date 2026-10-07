//
//  ClosingService.swift
//  Invo Billing
//

import Foundation

struct ClosingService {

    private let baseURL = AppEnvironment.baseURL

    // MARK: - Counting the floor

    func startStocktake(companyID: Int, note: String) async throws -> Int {
        let response: StartStocktakeResponse = try await send(
            "POST", "/stocktakes", companyID: companyID, body: ["note": note]
        )
        return response.stocktake_id
    }

    func stocktake(companyID: Int, id: Int) async throws -> Stocktake {
        try await send("GET", "/stocktakes/\(id)", companyID: companyID, body: Optional<[String: String]>.none)
    }

    func count(companyID: Int, stocktakeID: Int, itemID: Int, counted: Int) async throws {
        _ = try await send(
            "POST", "/stocktakes/\(stocktakeID)/count", companyID: companyID,
            body: ["item_id": itemID, "counted": counted]
        ) as EmptyClosingReply
    }

    func applyStocktake(companyID: Int, id: Int) async throws -> Int {
        let response: ApplyStocktakeResponse = try await send(
            "POST", "/stocktakes/\(id)/apply", companyID: companyID,
            body: Optional<[String: String]>.none
        )
        return response.items_adjusted
    }

    func abandonStocktake(companyID: Int, id: Int) async throws {
        _ = try await send(
            "DELETE", "/stocktakes/\(id)", companyID: companyID,
            body: Optional<[String: String]>.none
        ) as EmptyClosingReply
    }

    // MARK: - Counting the drawer

    func dayClosing(companyID: Int, date: Date) async throws -> DayClosing {
        try await send(
            "GET", "/day-closing?date=\(AppDate.wireString(from: date))",
            companyID: companyID, body: Optional<[String: String]>.none
        )
    }

    /// `opening` is sent only when somebody typed one. Left out, the server carries
    /// the drawer over from the last closing, which is what happens to a till overnight.
    func closeDay(
        companyID: Int, date: Date, counted: Double, opening: Double?, note: String
    ) async throws -> DayClosing {
        try await send("POST", "/day-closing", companyID: companyID, body: CloseDayRequest(
            date: AppDate.wireString(from: date),
            counted_cash: counted,
            opening_cash: opening,
            note: note
        ))
    }

    func recentClosings(companyID: Int) async throws -> [DayClosing] {
        let response: DayClosingsResponse = try await send(
            "GET", "/day-closings", companyID: companyID, body: Optional<[String: String]>.none
        )
        return response.data
    }

    // MARK: - Plumbing

    private func send<Body: Encodable, T: Decodable>(
        _ method: String, _ path: String, companyID: Int, body: Body?
    ) async throws -> T {
        // The path may already carry a query, so the company is appended rather than
        // assumed to be the first parameter.
        let joiner = path.contains("?") ? "&" : "?"
        guard let url = URL(string: "\(baseURL)\(path)\(joiner)company_id=\(companyID)") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        if let token = KeychainManager.shared.loadToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200...299).contains(http.statusCode) else {
            if let errorBody = try? JSONDecoder().decode(ClosingErrorBody.self, from: data),
               !errorBody.error.isEmpty {
                throw ClosingError(message: errorBody.error)
            }
            throw ClosingError(message: "That didn't work. Try again.")
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

private struct CloseDayRequest: Encodable {
    let date: String
    let counted_cash: Double
    /// Omitted entirely when nil, so the server can tell "carry it over" from "the
    /// float really was zero".
    let opening_cash: Double?
    let note: String
}

private struct ClosingErrorBody: Decodable { let error: String }

/// A reply whose body does not matter, only that it worked.
private struct EmptyClosingReply: Decodable {
    init(from decoder: Decoder) throws {}
}

struct ClosingError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
