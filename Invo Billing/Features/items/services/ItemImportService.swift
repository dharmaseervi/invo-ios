//
//  ItemImportService.swift
//  Invo Billing
//

import Foundation

/// Reads a catalogue file and, once the person has decided what to keep, writes it.
struct ItemImportService {

    private let baseURL = AppEnvironment.baseURL

    /// What the server makes of the file. Writes nothing.
    ///
    /// A workbook is sent as bytes rather than as text: an .xlsx is a zip, and reading
    /// it as a string produces nonsense. The server reads the first sheet and feeds it
    /// to the same parser the CSV path uses.
    func preview(
        companyID: Int,
        csv: String? = nil,
        workbook: Data? = nil,
        mapping: [String: ImportColumn] = [:]
    ) async throws -> ImportPreview {
        var body: [String: Any] = ["company_id": companyID]
        if let workbook {
            body["xlsx"] = workbook.base64EncodedString()
        } else {
            body["csv"] = csv ?? ""
        }
        if !mapping.isEmpty {
            body["mapping"] = mapping.mapValues(\.rawValue)
        }
        return try await send(path: "/items/import/preview", body: body)
    }

    /// Writes the chosen rows. All of them or none.
    func apply(companyID: Int, rows: [ImportAction]) async throws -> ImportResult {
        let encoded = try JSONEncoder().encode(rows)
        let rowsJSON = try JSONSerialization.jsonObject(with: encoded)
        return try await send(path: "/items/import", body: ["company_id": companyID, "rows": rowsJSON])
    }

    private func send<T: Decodable>(path: String, body: [String: Any]) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(path)") else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = KeychainManager.shared.loadToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        // A catalogue is bigger than anything else this app sends, and a slow connection
        // on a shop's phone should not lose an import that is already being processed.
        request.timeoutInterval = 120

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }

        guard (200...299).contains(http.statusCode) else {
            // The server's own sentence is the useful one here: which line, and what
            // about it. A generic failure would send somebody back to a spreadsheet
            // with no idea what to look for.
            if let payload = try? JSONDecoder().decode(ImportErrorResponse.self, from: data) {
                throw ImportError(message: payload.error, failures: payload.failed ?? [])
            }
            throw ImportError(message: "That didn't work. Try again.", failures: [])
        }

        return try JSONDecoder().decode(T.self, from: data)
    }
}

private struct ImportErrorResponse: Decodable {
    let error: String
    let failed: [ImportFailure]?
}

/// A refusal worth showing word for word.
struct ImportError: LocalizedError {
    let message: String
    let failures: [ImportFailure]

    var errorDescription: String? { message }
}
