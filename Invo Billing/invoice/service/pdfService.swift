//
//  InvoicePDFService.swift
//  Invo Billing
//
//  Updated for binary PDF response (not JSON)
//

import Foundation

final class InvoicePDFService {

    private let baseURL = AppEnvironment.baseURL

    // MARK: - Download PDF (Binary Response)

    /// Download PDF from server
    /// GET /api/v1/invoices/{invoiceID}/pdf
    /// Returns: Binary PDF data
    func downloadInvoicePDF(
        invoiceID: Int,
        copy: String = "original"
    ) async throws -> URL {

        guard
            let url = URL(
                string: "\(baseURL)/invoices/\(invoiceID)/pdf?copy=\(copy)"
            )
        else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/pdf", forHTTPHeaderField: "Accept")

        if let token = KeychainManager.shared.loadToken() {
            request.setValue(
                "Bearer \(token)",
                forHTTPHeaderField: "Authorization"
            )
        }

        print("📥 Downloading PDF (\(copy)) → \(url)")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200
        else {
            throw URLError(.badServerResponse)
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "Invoice_\(invoiceID)_\(copy.uppercased()).pdf"
            )

        try data.write(to: tempURL, options: .atomic)

        print("✅ PDF saved:", tempURL.lastPathComponent)
        return tempURL
    }

    // MARK: - Email PDF (Optional)

    /// Request server to email PDF
    /// POST /api/v1/invoices/{invoiceID}/pdf/email
    func emailInvoicePDF(
        invoiceID: Int,
        recipientEmail: String,
        message: String = ""
    ) async throws {
        guard
            let url = URL(string: "\(baseURL)/invoices/\(invoiceID)/pdf/email")
        else {
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

        let payload: [String: Any] = [
            "recipient_email": recipientEmail,
            "message": message,
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        print("📧 Emailing invoice to: \(recipientEmail)")

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200
        else {
            throw URLError(.badServerResponse)
        }

        print("✅ Invoice emailed successfully")
    }
}
