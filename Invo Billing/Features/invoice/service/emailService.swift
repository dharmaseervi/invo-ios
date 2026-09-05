//
//  emailService.swift
//  Invo Billing
//
//  Created by dharmaseervi on 3/17/26.
//

import Foundation

final class EmailService {
    
    private let baseURL = AppEnvironment.baseURL
    
    func sendInvoiceEmail(
        invoiceID: Int,
        toEmail: String,
        toName: String,
        token: String,
        isReminder: Bool = false
    ) async throws {
        guard let url = URL(string: "\(baseURL)/invoices/\(invoiceID)/send-email") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = ["to_email": toEmail, "to_name": toName, "reminder": isReminder]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
    }
}
