package com.loginscreen

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * ViewModel for the login screen following MVVM architecture.
 * Manages UI state, handles login logic, validation, and state updates.
 * Observes network state and implements lockout mechanism after 3 failures.
 *
 * @param authRepository Repository for authentication operations
 * @param networkMonitor Monitor for network connectivity state
 * @param tokenStorage Storage for persisting authentication tokens
 */
class LoginViewModel(
    private val authRepository: AuthRepository,
    private val networkMonitor: NetworkMonitor,
    private val tokenStorage: TokenStorage
) : ViewModel() {

    private val _uiState = MutableStateFlow(LoginUiState())
    val uiState: StateFlow<LoginUiState> = _uiState.asStateFlow()

    init {
        // Observe network state and update offline status
        viewModelScope.launch {
            networkMonitor.isOnline.collect { isOnline ->
                _uiState.update { it.copy(isOffline = !isOnline) }
            }
        }

        // Observe form validation and network state to enable/disable login button
        viewModelScope.launch {
            combine(
                _uiState,
                networkMonitor.isOnline
            ) { state, isOnline ->
                val isValid = state.username.isNotBlank() &&
                        state.password.isNotBlank() &&
                        !state.isLoading &&
                        !state.isLockedOut &&
                        isOnline
                state.copy(isButtonEnabled = isValid)
            }.collect { updatedState ->
                _uiState.update { updatedState }
            }
        }

        // Load saved token if remember me was enabled
        loadSavedToken()
    }

    /**
     * Updates the username in the UI state.
     * @param username The new username value
     */
    fun updateUsername(username: String) {
        _uiState.update { it.copy(username = username) }
    }

    /**
     * Updates the password in the UI state.
     * @param password The new password value
     */
    fun updatePassword(password: String) {
        _uiState.update { it.copy(password = password) }
    }

    /**
     * Updates the remember me checkbox state.
     * @param rememberMe The new remember me value
     */
    fun updateRememberMe(rememberMe: Boolean) {
        _uiState.update { it.copy(rememberMe = rememberMe) }
    }

    /**
     * Attempts to login with current username and password.
     * Validates state (not locked out, online, button enabled) before proceeding.
     * Updates failure count and locks account after 3 failures.
     */
    fun login() {
        val currentState = _uiState.value
        if (currentState.isLockedOut || currentState.isOffline || !currentState.isButtonEnabled) {
            return
        }

        viewModelScope.launch {
            _uiState.update {
                it.copy(
                    isLoading = true,
                    errorMessage = null
                )
            }

            val result = authRepository.login(
                currentState.username,
                currentState.password
            )

            _uiState.update { state ->
                result.fold(
                    onSuccess = { token ->
                        // Save token if remember me is enabled
                        if (state.rememberMe) {
                            tokenStorage.saveToken(token)
                        } else {
                            tokenStorage.clearToken()
                        }

                        state.copy(
                            isLoading = false,
                            errorMessage = null,
                            failureCount = 0,
                            navigationEvent = NavigationEvent.NavigateToHome
                        )
                    },
                    onFailure = { error ->
                        val newFailureCount = state.failureCount + 1
                        val isLockedOut = newFailureCount >= 3

                        state.copy(
                            isLoading = false,
                            errorMessage = error.message ?: "Login failed",
                            failureCount = newFailureCount,
                            isLockedOut = isLockedOut
                        )
                    }
                )
            }
        }
    }

    /**
     * Clears the current error message from the UI state.
     */
    fun clearError() {
        _uiState.update { it.copy(errorMessage = null) }
    }

    /**
     * Clears the navigation event after it has been consumed.
     */
    fun clearNavigationEvent() {
        _uiState.update { it.clearNavigationEvent() }
    }

    /**
     * Loads saved token on initialization and sets remember me if token exists.
     */
    private fun loadSavedToken() {
        viewModelScope.launch {
            val savedToken = tokenStorage.getToken()
            if (savedToken != null) {
                _uiState.update { it.copy(rememberMe = true) }
            }
        }
    }
}

/**
 * Interface for token storage operations.
 * Provides abstraction for persisting and retrieving authentication tokens.
 */
interface TokenStorage {
    /**
     * Saves an authentication token.
     * @param token The token to save
     */
    suspend fun saveToken(token: String)

    /**
     * Retrieves the saved authentication token.
     * @return The saved token, or null if no token exists
     */
    suspend fun getToken(): String?

    /**
     * Clears the saved authentication token.
     */
    suspend fun clearToken()
}

/**
 * Android implementation of TokenStorage using SharedPreferences.
 */
class TokenStorageImpl(private val context: android.content.Context) : TokenStorage {
    private val prefs = context.getSharedPreferences("auth_prefs", android.content.Context.MODE_PRIVATE)

    override suspend fun saveToken(token: String) {
        prefs.edit().putString("auth_token", token).apply()
    }

    override suspend fun getToken(): String? {
        return prefs.getString("auth_token", null)
    }

    override suspend fun clearToken() {
        prefs.edit().remove("auth_token").apply()
    }
}

