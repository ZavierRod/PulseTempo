//
//  PlaylistStorageManager.swift
//  PulseTempo
//
//  Created by Zavier Rodrigues on 11/17/25.
//

import Foundation

protocol PlaylistStorageManaging {
    func saveSelectedPlaylists(_ playlistIds: [String])
    func loadSelectedPlaylists() -> [String]
    func clearSelectedPlaylists()
    var hasSelectedPlaylists: Bool { get }
}

/// Manages persistent storage of selected playlist IDs
final class PlaylistStorageManager: PlaylistStorageManaging {
    
    // MARK: - Singleton
    
    static let shared = PlaylistStorageManager()

    private let userDefaults: UserDefaults
    private let suiteName: String?

    init(userDefaults: UserDefaults = .standard, suiteName: String? = nil) {
        self.userDefaults = userDefaults
        self.suiteName = suiteName
    }
    
    // MARK: - Storage Keys
    
    private enum StorageKey {
        static let selectedPlaylistIds = "selectedPlaylistIds"
    }
    
    // MARK: - Public Methods
    
    /// Save selected playlist IDs to UserDefaults
    func saveSelectedPlaylists(_ playlistIds: [String]) {
        userDefaults.set(playlistIds, forKey: StorageKey.selectedPlaylistIds)
        print("💾 Saved \(playlistIds.count) playlist IDs to storage")
    }
    
    /// Load selected playlist IDs from UserDefaults
    func loadSelectedPlaylists() -> [String] {
        let playlistIds = userDefaults.stringArray(forKey: StorageKey.selectedPlaylistIds) ?? []
        print("📂 Loaded \(playlistIds.count) playlist IDs from storage")
        return playlistIds
    }
    
    /// Clear all saved playlist selections
    func clearSelectedPlaylists() {
        if let suiteName {
            // Clearing the entire suite ensures stale test data doesn't linger between runs
            userDefaults.removePersistentDomain(forName: suiteName)
        } else {
            userDefaults.removeObject(forKey: StorageKey.selectedPlaylistIds)
        }
        print("🗑️ Cleared saved playlist selections")
    }
    
    /// Check if user has any saved playlists
    var hasSelectedPlaylists: Bool {
        return !loadSelectedPlaylists().isEmpty
    }
}
