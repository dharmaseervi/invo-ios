import Foundation

/// Thrown when the server rejects the stored token. Distinct from a transport failure
/// because retrying cannot help — the user has to sign in again.
struct SessionExpiredError: LocalizedError {
    var errorDescription: String? {
        "Your session has expired. Please sign in again."
    }
}
