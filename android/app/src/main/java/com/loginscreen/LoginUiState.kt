package com.loginscreen

/**
 * Immutable UI state for the login screen.
 * Contains all state needed to render the login UI.
 *
 * @param username Current username input
 * @param password Current password input
 * @param isLoading Whether login is in progress
 * @param errorMessage Error message to display, null if no error
 * @param isButtonEnabled Whether login button should be enabled
 * @param failureCount Number of consecutive login failures
 * @param isLockedOut Whether account is locked (after 3 failures)
 * @param isOffline Whether device is offline
 * @param rememberMe Whether "remember me" checkbox is checked
 * @param navigationEvent Navigation event to trigger, null if none
 */
data class LoginUiState(
    val username: String = "",
    val password: String = "",
    val isLoading: Boolean = false,
    val errorMessage: String? = null,
    val isButtonEnabled: Boolean = false,
    val failureCount: Int = 0,
    val isLockedOut: Boolean = false,
    val isOffline: Boolean = false,
    val rememberMe: Boolean = false,
    val navigationEvent: NavigationEvent? = null
) {
    /**
     * Clears the navigation event after it has been consumed.
     * @return New state with navigationEvent set to null
     */
    fun clearNavigationEvent() = copy(navigationEvent = null)
}

/**
 * Sealed class representing navigation events from the login screen.
 */
sealed class NavigationEvent {
    /**
     * Event to navigate to home screen after successful login.
     */
    object NavigateToHome : NavigationEvent()
}

