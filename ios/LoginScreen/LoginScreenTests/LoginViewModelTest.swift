import XCTest
import Combine

@MainActor
class LoginViewModelTest: XCTestCase {
    var authService: MockAuthService!
    var networkMonitor: MockNetworkMonitor!
    var tokenStorage: MockTokenStorage!
    var viewModel: LoginViewModel!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        authService = MockAuthService()
        networkMonitor = MockNetworkMonitor()
        tokenStorage = MockTokenStorage()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables = nil
        viewModel = nil
        tokenStorage = nil
        networkMonitor = nil
        authService = nil
        super.tearDown()
    }
    
    func testValidationEnablesDisablesButton() async {
        // Given: Network is online
        networkMonitor.isOnlineSubject.send(true)
        
        viewModel = LoginViewModel(
            authService: authService,
            networkMonitor: networkMonitor,
            tokenStorage: tokenStorage
        )
        
        // Wait for initial state
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // When: Username and password are empty
        var expectation = XCTestExpectation(description: "Button disabled when empty")
        viewModel.$state
            .map { $0.isButtonEnabled }
            .sink { isEnabled in
                if !isEnabled {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertFalse(viewModel.state.isButtonEnabled, "Button should be disabled when fields are empty")
        
        // When: Only username is filled
        viewModel.updateUsername("user")
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertFalse(viewModel.state.isButtonEnabled, "Button should be disabled when password is empty")
        
        // When: Only password is filled
        viewModel.updateUsername("")
        viewModel.updatePassword("password")
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertFalse(viewModel.state.isButtonEnabled, "Button should be disabled when username is empty")
        
        // When: Both fields are filled
        viewModel.updateUsername("user")
        viewModel.updatePassword("password")
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertTrue(viewModel.state.isButtonEnabled, "Button should be enabled when both fields are filled")
    }
    
    func testSuccessNavigationEvent() async {
        // Given: Network is online and valid credentials
        networkMonitor.isOnlineSubject.send(true)
        authService.loginResult = .success("token123")
        
        viewModel = LoginViewModel(
            authService: authService,
            networkMonitor: networkMonitor,
            tokenStorage: tokenStorage
        )
        
        viewModel.updateUsername("user")
        viewModel.updatePassword("password")
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // When: Valid credentials are entered and login is called
        viewModel.login()
        
        // Wait for async operation
        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
        
        // Then: Navigation event should be triggered
        XCTAssertNotNil(viewModel.state.navigationEvent, "Navigation event should be set")
        if case .navigateToHome = viewModel.state.navigationEvent {
            // Success
        } else {
            XCTFail("Navigation event should be navigateToHome")
        }
        XCTAssertNil(viewModel.state.errorMessage, "Error message should be null on success")
        XCTAssertEqual(viewModel.state.failureCount, 0, "Failure count should be reset")
    }
    
    func testErrorIncrementsFailureCount() async {
        // Given: Network is online and invalid credentials
        networkMonitor.isOnlineSubject.send(true)
        authService.loginResult = .failure(AuthError.invalidCredentials)
        
        viewModel = LoginViewModel(
            authService: authService,
            networkMonitor: networkMonitor,
            tokenStorage: tokenStorage
        )
        
        viewModel.updateUsername("wrong")
        viewModel.updatePassword("wrong")
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // When: Login fails
        viewModel.login()
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        
        // Then: Failure count should be incremented
        XCTAssertEqual(viewModel.state.failureCount, 1, "Failure count should be 1")
        XCTAssertNotNil(viewModel.state.errorMessage, "Error message should be set")
        XCTAssertFalse(viewModel.state.isLockedOut, "Should not be locked out after 1 failure")
        
        // When: Login fails again
        viewModel.login()
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        XCTAssertEqual(viewModel.state.failureCount, 2, "Failure count should be 2")
        XCTAssertFalse(viewModel.state.isLockedOut, "Should not be locked out after 2 failures")
    }
    
    func testLockoutAfter3Failures() async {
        // Given: Network is online and invalid credentials
        networkMonitor.isOnlineSubject.send(true)
        authService.loginResult = .failure(AuthError.invalidCredentials)
        
        viewModel = LoginViewModel(
            authService: authService,
            networkMonitor: networkMonitor,
            tokenStorage: tokenStorage
        )
        
        viewModel.updateUsername("wrong")
        viewModel.updatePassword("wrong")
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // When: Login fails 3 times
        viewModel.login()
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        XCTAssertEqual(viewModel.state.failureCount, 1, "Failure count should be 1")
        
        viewModel.login()
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        XCTAssertEqual(viewModel.state.failureCount, 2, "Failure count should be 2")
        
        viewModel.login()
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        
        // Then: Account should be locked out
        XCTAssertEqual(viewModel.state.failureCount, 3, "Failure count should be 3")
        XCTAssertTrue(viewModel.state.isLockedOut, "Account should be locked out")
        XCTAssertFalse(viewModel.state.isButtonEnabled, "Button should be disabled when locked out")
    }
    
    func testOfflineShowsMessageAndNoServiceCall() async {
        // Given: Network is offline
        networkMonitor.isOnlineSubject.send(false)
        
        viewModel = LoginViewModel(
            authService: authService,
            networkMonitor: networkMonitor,
            tokenStorage: tokenStorage
        )
        
        viewModel.updateUsername("user")
        viewModel.updatePassword("password")
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // When: User tries to login while offline
        // Then: Offline message should be shown
        XCTAssertTrue(viewModel.state.isOffline, "Should show offline state")
        XCTAssertFalse(viewModel.state.isButtonEnabled, "Button should be disabled when offline")
        
        // When: Login is attempted (should not call service)
        viewModel.login()
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        // Then: AuthService should not be called
        XCTAssertEqual(authService.loginCallCount, 0, "AuthService should not be called when offline")
    }
    
    func testRememberMePersistsToken() async {
        // Given: Network is online and valid credentials
        let testToken = "test_token_123"
        networkMonitor.isOnlineSubject.send(true)
        authService.loginResult = .success(testToken)
        
        viewModel = LoginViewModel(
            authService: authService,
            networkMonitor: networkMonitor,
            tokenStorage: tokenStorage
        )
        
        viewModel.updateUsername("user")
        viewModel.updatePassword("password")
        viewModel.updateRememberMe(true)
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // When: Login succeeds with remember me enabled
        viewModel.login()
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        
        // Then: Token should be saved
        XCTAssertTrue(tokenStorage.saveTokenCalled, "Token should be saved")
        XCTAssertEqual(tokenStorage.savedToken, testToken, "Correct token should be saved")
        
        // When: Remember me is disabled
        viewModel.updateRememberMe(false)
        viewModel.updateUsername("user2")
        viewModel.updatePassword("password2")
        authService.loginResult = .success("token2")
        viewModel.login()
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        
        // Then: Token should be cleared
        XCTAssertTrue(tokenStorage.clearTokenCalled, "Token should be cleared")
    }
}

// MARK: - Mock Classes

class MockAuthService: AuthServiceProtocol {
    var loginResult: Result<String, Error> = .success("default_token")
    var loginCallCount = 0
    
    func login(username: String, password: String) async throws -> String {
        loginCallCount += 1
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds for testing
        switch loginResult {
        case .success(let token):
            return token
        case .failure(let error):
            throw error
        }
    }
}

class MockNetworkMonitor: NetworkMonitorProtocol {
    let isOnlineSubject = CurrentValueSubject<Bool, Never>(true)
    
    var isOnline: AnyPublisher<Bool, Never> {
        isOnlineSubject.eraseToAnyPublisher()
    }
}

class MockTokenStorage: TokenStorageProtocol {
    var savedToken: String?
    var saveTokenCalled = false
    var clearTokenCalled = false
    
    func saveToken(_ token: String) async {
        savedToken = token
        saveTokenCalled = true
    }
    
    func getToken() async -> String? {
        return savedToken
    }
    
    func clearToken() async {
        savedToken = nil
        clearTokenCalled = true
    }
}

