//
//  PaymentService.swift
//  Invo Billing
//
//  Created by dharmaseervi on 12/31/25.
//


import Foundation

final class PaymentService {

    static let shared = PaymentService()
    private init() {}

    private let baseURL = AppEnvironment.baseURL

    func recordPayment(
        requestDTO: PaymentRequestDTO
    ) async throws {

        guard let url = URL(string: "\(baseURL)/payments") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = KeychainManager.shared.loadToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = try JSONEncoder().encode(requestDTO)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse,
              http.statusCode == 201 else {
            throw URLError(.badServerResponse)
        }
    }
}
