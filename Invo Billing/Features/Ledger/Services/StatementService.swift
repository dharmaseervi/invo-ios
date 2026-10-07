//
//  StatementService.swift
//  Invo Billing
//
//  Fetching a customer's statement of account as a PDF.
//

import Foundation

struct StatementService {

    private let baseURL = AppEnvironment.baseURL

    /// Downloads a customer's statement for a period and returns a file on disk, ready
    /// to be shown, printed or shared.
    ///
    /// Written to a filename built from the customer and the period rather than
    /// something generic: what leaves here through the share sheet lands in somebody's
    /// WhatsApp or Files, and "Statement.pdf" tells the person receiving it nothing.
    func statementPDF(
        companyID: Int,
        clientID: Int,
        clientName: String,
        from: Date,
        to: Date
    ) async throws -> URL {
        var components = URLComponents(string: "\(baseURL)/ledger/\(clientID)/statement.pdf")
        components?.queryItems = [
            URLQueryItem(name: "company_id", value: String(companyID)),
            URLQueryItem(name: "start", value: AppDate.wireString(from: from)),
            URLQueryItem(name: "end", value: AppDate.wireString(from: to)),
        ]
        guard let url = components?.url else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/pdf", forHTTPHeaderField: "Accept")
        // The ledger endpoints identify the company by header; the statement accepts
        // either, and sending both costs nothing and matches its siblings.
        request.setValue(String(companyID), forHTTPHeaderField: "X-Company-ID")
        if let token = KeychainManager.shared.loadToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard http.statusCode == 200 else {
            struct ErrorBody: Decodable { let error: String }
            if let body = try? JSONDecoder().decode(ErrorBody.self, from: data), !body.error.isEmpty {
                throw StatementError(message: body.error)
            }
            throw StatementError(message: "Couldn't build that statement.")
        }

        let name = "Statement_\(fileSafe(clientName))_\(AppDate.wireString(from: from)).pdf"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    /// Keeps a customer's name usable as a filename wherever it is opened.
    private func fileSafe(_ name: String) -> String {
        let cleaned = name.unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : "_"
        }
        let joined = String(cleaned).trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        return joined.isEmpty ? "Customer" : String(joined.prefix(40))
    }
}

struct StatementError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
