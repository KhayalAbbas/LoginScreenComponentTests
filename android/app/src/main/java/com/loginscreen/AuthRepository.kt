package com.loginscreen

import kotlinx.coroutines.delay

/**
 * Repository interface for authentication operations.
 * Provides abstraction for login functionality.
 */
interface AuthRepository {
    /**
     * Attempts to authenticate user with provided credentials.
     *
     * @param username The username to authenticate
     * @param password The password to authenticate
     * @return Result containing token on success, or error on failure
     */
    suspend fun login(username: String, password: String): Result<String>
}

/**
 * Implementation of AuthRepository.
 * Simulates network authentication with mock credentials.
 */
class AuthRepositoryImpl : AuthRepository {
    /**
     * Authenticates user credentials.
     * For testing: accepts "user"/"password" as valid credentials.
     *
     * @param username The username to authenticate
     * @param password The password to authenticate
     * @return Result.success with token if credentials are valid,
     *         Result.failure with error message otherwise
     */
    override suspend fun login(username: String, password: String): Result<String> {
        // Simulate network delay
        delay(1000)
        
        // Simulate authentication logic
        return if (username == "user" && password == "password") {
            Result.success("mock_token_${System.currentTimeMillis()}")
        } else {
            Result.failure(Exception("Invalid credentials"))
        }
    }
}

