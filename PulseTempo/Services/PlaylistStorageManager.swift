//
//  PlaylistStorageManager.swift
//  PulseTempo
//
//  Created by Zavier Rodrigues on 11/17/25.
//

import Foundation

/// Manages persistent storage of selected playlist IDs
final class PlaylistStorageManager {
    
    // MARK: - Singleton
    
    static let shared = PlaylistStorageManager()
    
    private init() {}
    
    // MARK: - Storage Keys
    
    private enum StorageKey {
        static let selectedPlaylistIds = "selectedPlaylistIds"
    }
    
    // MARK: - Public Methods
    
    /// Save selected playlist IDs to UserDefaults
    func saveSelectedPlaylists(_ playlistIds: [String]) {
        UserDefaults.standard.set(playlistIds, forKey: StorageKey.selectedPlaylistIds)
        print("💾 Saved \(playlistIds.count) playlist IDs to storage")
    }
    
    /// Load selected playlist IDs from UserDefaults
    func loadSelectedPlaylists() -> [String] {
        let playlistIds = UserDefaults.standard.stringArray(forKey: StorageKey.selectedPlaylistIds) ?? []
        print("📂 Loaded \(playlistIds.count) playlist IDs from storage")
        return playlistIds
    }
    
    /// Clear all saved playlist selections
    func clearSelectedPlaylists() {
        UserDefaults.standard.removeObject(forKey: StorageKey.selectedPlaylistIds)
        print("🗑️ Cleared saved playlist selections")
    }
    
    /// Check if user has any saved playlists
    var hasSelectedPlaylists: Bool {
        return !loadSelectedPlaylists().isEmpty
    }
}
