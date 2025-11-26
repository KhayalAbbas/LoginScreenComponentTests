import Foundation

/// UI state for the login screen.
/// Contains all state needed to render the login UI.
struct LoginState {
    /// Current username input
    var username: String = ""
    /// Current password input
    var password: String = ""
    /// Whether login is in progress
    var isLoading: Bool = false
    /// Error message to display, nil if no error
    var errorMessage: String? = nil
    /// Whether login button should be enabled
    var isButtonEnabled: Bool = false
    /// Number of consecutive login failures
    var failureCount: Int = 0
    /// Whether account is locked (after 3 failures)
    var isLockedOut: Bool = false
    /// Whether device is offline
    var isOffline: Bool = false
    /// Whether "remember me" checkbox is checked
    var rememberMe: Bool = false
    /// Navigation event to trigger, nil if none
    var navigationEvent: NavigationEvent? = nil
}

/// Navigation events from the login screen.
enum NavigationEvent {
    /// Event to navigate to home screen after successful login.
    case navigateToHome
}

