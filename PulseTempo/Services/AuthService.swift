//
//  AuthService.swift
//  PulseTempo
//
//  Created by Zavier Rodrigues on 1/28/26.
//

import Foundation
import Combine

// ═══════════════════════════════════════════════════════════
// AUTH SERVICE
// ═══════════════════════════════════════════════════════════
// Manages user authentication with email/password
// Communicates with backend /api/auth endpoints
//
// Python/FastAPI analogy:
// Like an API client class that handles authentication
// Similar to a requests-based auth client with token management

/// User model for authenticated user
struct AuthUser: Codable, Identifiable {
    let id: String
    let email: String?
    let firstName: String?
    let lastName: String?
    let createdAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case firstName = "first_name"
        case lastName = "last_name"
        case createdAt = "created_at"
    }
}

/// Token response from auth endpoints
struct AuthTokenResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
    }
}

/// Authentication errors
enum AuthError: LocalizedError {
    case invalidCredentials
    case emailAlreadyExists
    case networkError(String)
    case serverError(String)
    case notAuthenticated
    
    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Incorrect email or password"
        case .emailAlreadyExists:
            return "An account with this email already exists"
        case .networkError(let message):
            return "Network error: \(message)"
        case .serverError(let message):
            return "Server error: \(message)"
        case .notAuthenticated:
            return "You are not logged in"
        }
    }
}

/// Manages user authentication state and API calls
class AuthService: ObservableObject {
    
    // SINGLETON PATTERN
    static let shared = AuthService()
    
    // MARK: - Published Properties (Observable State)
    
    /// Whether the user is currently authenticated
    @Published var isAuthenticated: Bool = false
    
    /// Current authenticated user (nil if not logged in)
    @Published var currentUser: AuthUser?
    
    /// Loading state for async operations
    @Published var isLoading: Bool = false
    
    /// Error message to display
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    
    private let keychainManager = KeychainManager.shared
    
    // Backend URL - Railway production server
    private let baseURL: String = "https://pulsetempo-production.up.railway.app"
    
    // MARK: - Initialization
    
    private init() {
        // Check if user has stored tokens on app launch
        checkAuthenticationStatus()
    }
    
    /// Check if user is already authenticated from stored tokens
    func checkAuthenticationStatus() {
        if keychainManager.hasTokens {
            isAuthenticated = true
            print("🔐 [Auth] User has stored tokens - authenticated")
            // Optionally fetch user info here
        } else {
            isAuthenticated = false
            print("🔐 [Auth] No stored tokens - not authenticated")
        }
    }
    
    // MARK: - Registration
    
    /// Register a new user with email and password
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password
    ///   - firstName: Optional first name
    ///   - lastName: Optional last name
    func register(
        email: String,
        password: String,
        firstName: String? = nil,
        lastName: String? = nil
    ) async throws {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        defer {
            Task { @MainActor in
                isLoading = false
            }
        }
        
        let url = URL(string: "\(baseURL)/api/auth/register")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Build request body
        var body: [String: Any] = [
            "email": email,
            "password": password
        ]
        if let firstName = firstName {
            body["first_name"] = firstName
        }
        if let lastName = lastName {
            body["last_name"] = lastName
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AuthError.networkError("Invalid response")
            }
            
            switch httpResponse.statusCode {
            case 200:
                let tokenResponse = try JSONDecoder().decode(AuthTokenResponse.self, from: data)
                await handleSuccessfulAuth(tokenResponse: tokenResponse)
                print("✅ [Auth] Registration successful for \(email)")
                
            case 400:
                // Email already exists
                throw AuthError.emailAlreadyExists
                
            default:
                let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw AuthError.serverError(errorBody)
            }
            
        } catch let error as AuthError {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
            throw error
        } catch {
            let authError = AuthError.networkError(error.localizedDescription)
            await MainActor.run {
                errorMessage = authError.localizedDescription
            }
            throw authError
        }
    }
    
    // MARK: - Login
    
    /// Login with email and password
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password
    func login(email: String, password: String) async throws {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        defer {
            Task { @MainActor in
                isLoading = false
            }
        }
        
        let url = URL(string: "\(baseURL)/api/auth/login/email")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "email": email,
            "password": password
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AuthError.networkError("Invalid response")
            }
            
            switch httpResponse.statusCode {
            case 200:
                let tokenResponse = try JSONDecoder().decode(AuthTokenResponse.self, from: data)
                await handleSuccessfulAuth(tokenResponse: tokenResponse)
                print("✅ [Auth] Login successful for \(email)")
                
            case 401:
                throw AuthError.invalidCredentials
                
            default:
                let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw AuthError.serverError(errorBody)
            }
            
        } catch let error as AuthError {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
            throw error
        } catch {
            let authError = AuthError.networkError(error.localizedDescription)
            await MainActor.run {
                errorMessage = authError.localizedDescription
            }
            throw authError
        }
    }
    
    // MARK: - Logout
    
    /// Log out the current user
    func logout() {
        keychainManager.clearAll()
        
        Task { @MainActor in
            isAuthenticated = false
            currentUser = nil
            errorMessage = nil
        }
        
        print("👋 [Auth] User logged out")
    }
    
    // MARK: - Token Access
    
    /// Get the current access token for API requests
    func getAccessToken() -> String? {
        return keychainManager.getAccessToken()
    }
    
    /// Get the current refresh token
    func getRefreshToken() -> String? {
        return keychainManager.getRefreshToken()
    }
    
    // MARK: - Token Refresh
    
    /// Attempt to refresh the access token using the stored refresh token.
    /// Returns `true` if new tokens were saved successfully, `false` otherwise.
    /// On failure the user is logged out so they can re-authenticate.
    func refreshTokens() async -> Bool {
        guard let refreshToken = keychainManager.getRefreshToken() else {
            print("🔐 [Auth] No refresh token available - logging out")
            logout()
            return false
        }
        
        let url = URL(string: "\(baseURL)/api/auth/refresh")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["refresh_token": refreshToken]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("🔐 [Auth] Token refresh failed - logging out")
                logout()
                return false
            }
            
            let tokenResponse = try JSONDecoder().decode(AuthTokenResponse.self, from: data)
            await handleSuccessfulAuth(tokenResponse: tokenResponse)
            print("🔐 [Auth] Tokens refreshed successfully")
            return true
        } catch {
            print("🔐 [Auth] Token refresh error: \(error.localizedDescription) - logging out")
            logout()
            return false
        }
    }
    
    // MARK: - Private Helpers
    
    /// Handle successful authentication (save tokens, update state)
    @MainActor
    private func handleSuccessfulAuth(tokenResponse: AuthTokenResponse) {
        // Save tokens to keychain
        keychainManager.saveTokens(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken
        )
        
        // Update state
        isAuthenticated = true
        errorMessage = nil
    }
    
    /// Clear error message
    func clearError() {
        errorMessage = nil
    }
}
