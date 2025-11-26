package com.loginscreen

import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.test.setMain
import kotlinx.coroutines.test.resetMain
import org.junit.Assert.*
import org.junit.Before
import org.junit.After
import org.junit.Test
import org.mockito.kotlin.*

class LoginViewModelTest {

    private lateinit var authRepository: AuthRepository
    private lateinit var networkMonitor: NetworkMonitor
    private lateinit var tokenStorage: TokenStorage
    private lateinit var viewModel: LoginViewModel
    private val testDispatcher = StandardTestDispatcher()

    @Before
    fun setup() {
        Dispatchers.setMain(testDispatcher)
        authRepository = mock()
        networkMonitor = mock()
        tokenStorage = mock()
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun `test validation enables disables button`() = runTest(testDispatcher) {
        // Given: Network is online
        whenever(networkMonitor.isOnline).thenReturn(
            kotlinx.coroutines.flow.flowOf(true)
        )

        viewModel = LoginViewModel(authRepository, networkMonitor, tokenStorage)

        // When: Username and password are empty
        var state = viewModel.uiState.first()
        assertFalse("Button should be disabled when fields are empty", state.isButtonEnabled)

        // When: Only username is filled
        viewModel.updateUsername("user")
        advanceUntilIdle()
        state = viewModel.uiState.first()
        assertFalse("Button should be disabled when password is empty", state.isButtonEnabled)

        // When: Only password is filled
        viewModel.updatePassword("")
        viewModel.updateUsername("")
        viewModel.updatePassword("password")
        advanceUntilIdle()
        state = viewModel.uiState.first()
        assertFalse("Button should be disabled when username is empty", state.isButtonEnabled)

        // When: Both fields are filled
        viewModel.updateUsername("user")
        viewModel.updatePassword("password")
        advanceUntilIdle()
        state = viewModel.uiState.first()
        assertTrue("Button should be enabled when both fields are filled", state.isButtonEnabled)
    }

    @Test
    fun `test success navigation event`() = runTest(testDispatcher) {
        // Given: Network is online and valid credentials
        whenever(networkMonitor.isOnline).thenReturn(
            kotlinx.coroutines.flow.flowOf(true)
        )
        whenever(authRepository.login("user", "password")).thenReturn(
            Result.success("token123")
        )

        viewModel = LoginViewModel(authRepository, networkMonitor, tokenStorage)

        // When: Valid credentials are entered and login is called
        viewModel.updateUsername("user")
        viewModel.updatePassword("password")
        advanceUntilIdle()

        viewModel.login()
        advanceUntilIdle()

        // Then: Navigation event should be triggered
        val state = viewModel.uiState.first()
        assertNotNull("Navigation event should be set", state.navigationEvent)
        assertTrue("Navigation event should be NavigateToHome", 
            state.navigationEvent is NavigationEvent.NavigateToHome)
        assertNull("Error message should be null on success", state.errorMessage)
        assertEquals("Failure count should be reset", 0, state.failureCount)
    }

    @Test
    fun `test error increments failure count`() = runTest(testDispatcher) {
        // Given: Network is online and invalid credentials
        whenever(networkMonitor.isOnline).thenReturn(
            kotlinx.coroutines.flow.flowOf(true)
        )
        whenever(authRepository.login(any(), any())).thenReturn(
            Result.failure(Exception("Invalid credentials"))
        )

        viewModel = LoginViewModel(authRepository, networkMonitor, tokenStorage)

        viewModel.updateUsername("wrong")
        viewModel.updatePassword("wrong")
        advanceUntilIdle()

        // When: Login fails
        viewModel.login()
        advanceUntilIdle()

        // Then: Failure count should be incremented
        var state = viewModel.uiState.first()
        assertEquals("Failure count should be 1", 1, state.failureCount)
        assertNotNull("Error message should be set", state.errorMessage)
        assertFalse("Should not be locked out after 1 failure", state.isLockedOut)

        // When: Login fails again
        viewModel.login()
        advanceUntilIdle()
        state = viewModel.uiState.first()
        assertEquals("Failure count should be 2", 2, state.failureCount)
        assertFalse("Should not be locked out after 2 failures", state.isLockedOut)
    }

    @Test
    fun `test lockout after 3 failures`() = runTest(testDispatcher) {
        // Given: Network is online and invalid credentials
        whenever(networkMonitor.isOnline).thenReturn(
            kotlinx.coroutines.flow.flowOf(true)
        )
        whenever(authRepository.login(any(), any())).thenReturn(
            Result.failure(Exception("Invalid credentials"))
        )

        viewModel = LoginViewModel(authRepository, networkMonitor, tokenStorage)

        viewModel.updateUsername("wrong")
        viewModel.updatePassword("wrong")
        advanceUntilIdle()

        // When: Login fails 3 times
        viewModel.login()
        advanceUntilIdle()
        var state = viewModel.uiState.first()
        assertEquals("Failure count should be 1", 1, state.failureCount)

        viewModel.login()
        advanceUntilIdle()
        state = viewModel.uiState.first()
        assertEquals("Failure count should be 2", 2, state.failureCount)

        viewModel.login()
        advanceUntilIdle()
        state = viewModel.uiState.first()

        // Then: Account should be locked out
        assertEquals("Failure count should be 3", 3, state.failureCount)
        assertTrue("Account should be locked out", state.isLockedOut)
        assertFalse("Button should be disabled when locked out", state.isButtonEnabled)
    }

    @Test
    fun `test offline shows message and no service call`() = runTest(testDispatcher) {
        // Given: Network is offline
        whenever(networkMonitor.isOnline).thenReturn(
            kotlinx.coroutines.flow.flowOf(false)
        )

        viewModel = LoginViewModel(authRepository, networkMonitor, tokenStorage)

        viewModel.updateUsername("user")
        viewModel.updatePassword("password")
        advanceUntilIdle()

        // When: User tries to login while offline
        val state = viewModel.uiState.first()
        
        // Then: Offline message should be shown
        assertTrue("Should show offline state", state.isOffline)
        assertFalse("Button should be disabled when offline", state.isButtonEnabled)

        // When: Login is attempted (should not call service)
        viewModel.login()
        advanceUntilIdle()

        // Then: AuthRepository should not be called
        verify(authRepository, never()).login(any(), any())
    }

    @Test
    fun `test remember me persists token`() = runTest(testDispatcher) {
        // Given: Network is online and valid credentials
        val testToken = "test_token_123"
        whenever(networkMonitor.isOnline).thenReturn(
            kotlinx.coroutines.flow.flowOf(true)
        )
        whenever(authRepository.login("user", "password")).thenReturn(
            Result.success(testToken)
        )

        viewModel = LoginViewModel(authRepository, networkMonitor, tokenStorage)

        viewModel.updateUsername("user")
        viewModel.updatePassword("password")
        viewModel.updateRememberMe(true)
        advanceUntilIdle()

        // When: Login succeeds with remember me enabled
        viewModel.login()
        advanceUntilIdle()

        // Then: Token should be saved
        verify(tokenStorage).saveToken(testToken)

        // When: Remember me is disabled
        viewModel.updateRememberMe(false)
        viewModel.updateUsername("user2")
        viewModel.updatePassword("password2")
        whenever(authRepository.login("user2", "password2")).thenReturn(
            Result.success("token2")
        )
        viewModel.login()
        advanceUntilIdle()

        // Then: Token should be cleared
        verify(tokenStorage).clearToken()
    }
}

