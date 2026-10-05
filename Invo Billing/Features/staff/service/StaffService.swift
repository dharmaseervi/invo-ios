//
//  StaffService.swift
//  Invo Billing
//

import Foundation

struct StaffService {

    private let baseURL = AppEnvironment.baseURL

    func members(companyID: Int) async throws -> [StaffMember] {
        let response: StaffResponse = try await send(
            "GET", "/companies/\(companyID)/staff", body: Optional<NewStaffRequest>.none
        )
        return response.data
    }

    func add(companyID: Int, request: NewStaffRequest) async throws {
        _ = try await send(
            "POST", "/companies/\(companyID)/staff", body: request
        ) as EmptyStaffReply
    }

    func update(companyID: Int, memberID: Int, request: UpdateStaffRequest) async throws {
        _ = try await send(
            "PUT", "/companies/\(companyID)/staff/\(memberID)", body: request
        ) as EmptyStaffReply
    }

    func remove(companyID: Int, memberID: Int) async throws {
        _ = try await send(
            "DELETE", "/companies/\(companyID)/staff/\(memberID)",
            body: Optional<NewStaffRequest>.none
        ) as EmptyStaffReply
    }

    // MARK: - Plumbing

    private func send<Body: Encodable, T: Decodable>(
        _ method: String, _ path: String, body: Body?
    ) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(path)") else { throw URLError(.badURL) }

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
            // The server's own sentence where there is one. "They already work here"
            // is an answer; "something went wrong" is not.
            if let body = try? JSONDecoder().decode(StaffErrorBody.self, from: data),
               !body.error.isEmpty {
                throw StaffError(message: body.error)
            }
            throw StaffError(message: "That didn't work. Try again.")
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

private struct StaffErrorBody: Decodable { let error: String }

/// A reply whose body does not matter, only that it worked.
private struct EmptyStaffReply: Decodable {
    init(from decoder: Decoder) throws {}
}

struct StaffError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
