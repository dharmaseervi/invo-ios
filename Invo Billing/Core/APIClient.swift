import Foundation

/// One transport for API calls. Refreshes are shared across concurrent requests;
/// a session change invalidates in-flight results from the previous account.
@MainActor
final class APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private var refreshID: UUID?
    private var refreshTask: Task<TokenRefreshResponse, Error>?
    private let publicPaths: Set<String> = [
        "login", "register", "verify-email", "resend-verification", "send-otp",
        "verify-otp", "forgot-password", "reset-password"
    ]

    init(session: URLSession? = nil) {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 90
        configuration.httpShouldSetCookies = false
        self.session = session ?? URLSession(configuration: configuration)
    }

    func data(for original: URLRequest) async throws -> (Data, URLResponse) {
        guard let url = original.url, let api = URL(string: AppEnvironment.baseURL),
              url.scheme == api.scheme, url.host == api.host, url.port == api.port,
              url.path.hasPrefix(api.path + "/") else {
            throw URLError(.badURL)
        }
        let path = String(url.path.dropFirst(api.path.count + 1))
        let isAuthenticated = !publicPaths.contains(path) && !path.hasPrefix("public/")
        let generation = SessionManager.shared.credentialGeneration
        var request = original
        request.timeoutInterval = min(original.timeoutInterval, 30)
        if isAuthenticated {
            if let token = KeychainManager.shared.loadToken(),
               tokenExpiresWithin(token, seconds: 60),
               KeychainManager.shared.loadRefreshToken() != nil {
                _ = try await refreshAccessToken()
            }
            try Task.checkCancellation()
            guard generation == SessionManager.shared.credentialGeneration,
                  let token = KeychainManager.shared.loadToken() else { throw SessionExpiredError() }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let result = try await session.data(for: request)
        try Task.checkCancellation()
        guard !isAuthenticated || generation == SessionManager.shared.credentialGeneration else {
            throw CancellationError()
        }
        guard isAuthenticated, (result.1 as? HTTPURLResponse)?.statusCode == 401 else { return result }

        // A concurrent request may already have rotated the access token.
        if request.value(forHTTPHeaderField: "Authorization") == KeychainManager.shared.loadToken().map({ "Bearer \($0)" }) {
            _ = try await refreshAccessToken()
        }
        guard generation == SessionManager.shared.credentialGeneration else { throw SessionExpiredError() }
        let method = request.httpMethod ?? "GET"
        guard method == "GET" || method == "HEAD" else {
            // Never replay a financial mutation automatically. A proactive refresh
            // normally handles expiry before submission; this case needs a new tap.
            throw SessionRenewedError()
        }
        guard let token = KeychainManager.shared.loadToken() else { throw SessionExpiredError() }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let retried = try await session.data(for: request)
        try Task.checkCancellation()
        guard generation == SessionManager.shared.credentialGeneration else { throw CancellationError() }
        if (retried.1 as? HTTPURLResponse)?.statusCode == 401 {
            SessionManager.shared.clearLocalSession()
            throw SessionExpiredError()
        }
        return retried
    }

    func refreshAccessToken() async throws -> TokenRefreshResponse {
        if let refreshTask { return try await refreshTask.value }
        guard let credential = KeychainManager.shared.loadRefreshToken() else {
            SessionManager.shared.clearLocalSession()
            throw SessionExpiredError()
        }
        let generation = SessionManager.shared.credentialGeneration
        let task = Task<TokenRefreshResponse, Error> {
            guard let url = URL(string: AppEnvironment.baseURL + "/auth/token/refresh") else { throw URLError(.badURL) }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(["refresh_token": credential])
            let (data, response) = try await self.session.data(for: request)
            guard generation == SessionManager.shared.credentialGeneration,
                  credential == KeychainManager.shared.loadRefreshToken() else { throw CancellationError() }
            guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
            if http.statusCode == 401 || http.statusCode == 403 {
                SessionManager.shared.clearLocalSession()
                throw SessionExpiredError()
            }
            guard (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
            let decoded = try JSONDecoder().decode(TokenRefreshResponse.self, from: data)
            try SessionManager.shared.storeCredentials(token: decoded.token, refreshToken: decoded.refresh_token,
                                                       sessionID: decoded.session_id, replacingSession: false)
            return decoded
        }
        let id = UUID()
        refreshID = id
        refreshTask = task
        defer { if refreshID == id { refreshTask = nil; refreshID = nil } }
        return try await task.value
    }

    func cancelRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
        refreshID = nil
    }
}

struct SessionRenewedError: LocalizedError {
    var errorDescription: String? { "Your session was renewed. Please submit again." }
}
