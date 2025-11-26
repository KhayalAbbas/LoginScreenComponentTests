import Foundation
import Combine

/// ViewModel for the login screen following MVVM architecture.
/// Manages UI state, handles login logic, validation, and state updates.
/// Observes network state and implements lockout mechanism after 3 failures.
@MainActor
class LoginViewModel: ObservableObject {
    /// Published state that triggers UI updates when changed.
    @Published var state = LoginState()
    
    private let authService: AuthServiceProtocol
    private let networkMonitor: NetworkMonitorProtocol
    private let tokenStorage: TokenStorageProtocol
    private var cancellables = Set<AnyCancellable>()
    
    /// Initializes the ViewModel with required dependencies.
    ///
    /// - Parameters:
    ///   - authService: Service for authentication operations
    ///   - networkMonitor: Monitor for network connectivity state
    ///   - tokenStorage: Storage for persisting authentication tokens
    init(
        authService: AuthServiceProtocol,
        networkMonitor: NetworkMonitorProtocol,
        tokenStorage: TokenStorageProtocol
    ) {
        self.authService = authService
        self.networkMonitor = networkMonitor
        self.tokenStorage = tokenStorage
        
        setupNetworkMonitoring()
        setupValidation()
        loadSavedToken()
    }
    
    /// Updates the username in the UI state.
    /// - Parameter username: The new username value
    func updateUsername(_ username: String) {
        state.username = username
    }
    
    /// Updates the password in the UI state.
    /// - Parameter password: The new password value
    func updatePassword(_ password: String) {
        state.password = password
    }
    
    /// Updates the remember me checkbox state.
    /// - Parameter rememberMe: The new remember me value
    func updateRememberMe(_ rememberMe: Bool) {
        state.rememberMe = rememberMe
    }
    
    /// Attempts to login with current username and password.
    /// Validates state (not locked out, online, button enabled) before proceeding.
    /// Updates failure count and locks account after 3 failures.
    func login() {
        guard !state.isLockedOut, !state.isOffline, state.isButtonEnabled else {
            return
        }
        
        state.isLoading = true
        state.errorMessage = nil
        
        Task {
            do {
                let token = try await authService.login(
                    username: state.username,
                    password: state.password
                )
                
                // Save token if remember me is enabled
                if state.rememberMe {
                    await tokenStorage.saveToken(token)
                } else {
                    await tokenStorage.clearToken()
                }
                
                state.isLoading = false
                state.errorMessage = nil
                state.failureCount = 0
                state.navigationEvent = .navigateToHome
            } catch {
                let newFailureCount = state.failureCount + 1
                let isLockedOut = newFailureCount >= 3
                
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                state.failureCount = newFailureCount
                state.isLockedOut = isLockedOut
            }
        }
    }
    
    /// Clears the current error message from the UI state.
    func clearError() {
        state.errorMessage = nil
    }
    
    /// Clears the navigation event after it has been consumed.
    func clearNavigationEvent() {
        state.navigationEvent = nil
    }
    
    /// Sets up network monitoring to update offline state reactively.
    private func setupNetworkMonitoring() {
        networkMonitor.isOnline
            .receive(on: DispatchQueue.main)
            .map { !$0 }
            .assign(to: \.state.isOffline, on: self)
            .store(in: &cancellables)
    }
    
    /// Sets up form validation to enable/disable login button reactively.
    /// Button is enabled when: fields are not empty, not loading, not locked out, and online.
    private func setupValidation() {
        $state
            .combineLatest(networkMonitor.isOnline)
            .map { state, isOnline in
                !state.username.isEmpty &&
                !state.password.isEmpty &&
                !state.isLoading &&
                !state.isLockedOut &&
                isOnline
            }
            .assign(to: \.state.isButtonEnabled, on: self)
            .store(in: &cancellables)
    }
    
    /// Loads saved token on initialization and sets remember me if token exists.
    private func loadSavedToken() {
        Task {
            let savedToken = await tokenStorage.getToken()
            if savedToken != nil {
                state.rememberMe = true
            }
        }
    }
}

/// Protocol for token storage operations.
/// Provides abstraction for persisting and retrieving authentication tokens.
protocol TokenStorageProtocol {
    /// Saves an authentication token.
    /// - Parameter token: The token to save
    func saveToken(_ token: String) async
    
    /// Retrieves the saved authentication token.
    /// - Returns: The saved token, or nil if no token exists
    func getToken() async -> String?
    
    /// Clears the saved authentication token.
    func clearToken() async
}

/// iOS implementation of TokenStorageProtocol using UserDefaults.
class TokenStorage: TokenStorageProtocol {
    private let userDefaults = UserDefaults.standard
    private let tokenKey = "auth_token"
    
    func saveToken(_ token: String) async {
        userDefaults.set(token, forKey: tokenKey)
    }
    
    func getToken() async -> String? {
        return userDefaults.string(forKey: tokenKey)
    }
    
    func clearToken() async {
        userDefaults.removeObject(forKey: tokenKey)
    }
}

