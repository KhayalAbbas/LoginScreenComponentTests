import Foundation

/// Protocol for authentication service operations.
/// Provides abstraction for login functionality.
protocol AuthServiceProtocol {
    /// Attempts to authenticate user with provided credentials.
    ///
    /// - Parameters:
    ///   - username: The username to authenticate
    ///   - password: The password to authenticate
    /// - Returns: Authentication token on success
    /// - Throws: AuthError if credentials are invalid
    func login(username: String, password: String) async throws -> String
}

/// Implementation of AuthServiceProtocol.
/// Simulates network authentication with mock credentials.
class AuthService: AuthServiceProtocol {
    /// Authenticates user credentials.
    /// For testing: accepts "user"/"password" as valid credentials.
    ///
    /// - Parameters:
    ///   - username: The username to authenticate
    ///   - password: The password to authenticate
    /// - Returns: Authentication token string
    /// - Throws: AuthError.invalidCredentials if credentials are invalid
    func login(username: String, password: String) async throws -> String {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Simulate authentication logic
        if username == "user" && password == "password" {
            return "mock_token_\(Date().timeIntervalSince1970)"
        } else {
            throw AuthError.invalidCredentials
        }
    }
}

/// Authentication errors that can occur during login.
enum AuthError: Error, LocalizedError {
    case invalidCredentials
    
    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid credentials"
        }
    }
}

