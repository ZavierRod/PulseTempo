//
//  KeychainManager.swift
//  PulseTempo
//
//  Created by Zavier Rodrigues on 1/28/26.
//

import Foundation
import Security

// ═══════════════════════════════════════════════════════════
// KEYCHAIN MANAGER
// ═══════════════════════════════════════════════════════════
// Securely stores authentication tokens in iOS Keychain
// Keychain data persists across app reinstalls and is encrypted
//
// Python/FastAPI analogy:
// Like storing secrets in environment variables or a secure vault
// Similar to using python-dotenv with encrypted storage

/// Manages secure storage of authentication tokens in iOS Keychain
class KeychainManager {
    
    // SINGLETON PATTERN
    static let shared = KeychainManager()
    
    // MARK: - Keys
    private let accessTokenKey = "com.pulsetempo.accessToken"
    private let refreshTokenKey = "com.pulsetempo.refreshToken"
    private let userIdKey = "com.pulsetempo.userId"
    
    private init() {}
    
    // MARK: - Token Management
    
    /// Save both access and refresh tokens
    func saveTokens(accessToken: String, refreshToken: String) {
        save(key: accessTokenKey, value: accessToken)
        save(key: refreshTokenKey, value: refreshToken)
        print("🔐 [Keychain] Tokens saved")
    }
    
    /// Get the current access token
    func getAccessToken() -> String? {
        return load(key: accessTokenKey)
    }
    
    /// Get the current refresh token
    func getRefreshToken() -> String? {
        return load(key: refreshTokenKey)
    }
    
    /// Save user ID for reference
    func saveUserId(_ userId: String) {
        save(key: userIdKey, value: userId)
    }
    
    /// Get saved user ID
    func getUserId() -> String? {
        return load(key: userIdKey)
    }
    
    /// Clear all stored authentication data (logout)
    func clearAll() {
        delete(key: accessTokenKey)
        delete(key: refreshTokenKey)
        delete(key: userIdKey)
        print("🔐 [Keychain] All tokens cleared")
    }
    
    /// Check if user has stored tokens (is logged in)
    var hasTokens: Bool {
        return getAccessToken() != nil
    }
    
    // MARK: - Low-Level Keychain Operations
    
    /// Save a string value to keychain
    private func save(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        
        // First, try to delete any existing item
        delete(key: key)
        
        // Create query for new item
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("⚠️ [Keychain] Failed to save \(key): \(status)")
        }
    }
    
    /// Load a string value from keychain
    private func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return value
    }
    
    /// Delete a value from keychain
    private func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}
