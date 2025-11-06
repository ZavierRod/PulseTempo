//
//  PlaylistSelectionViewModel.swift
//  PulseTempo
//
//  Created by Zavier Rodrigues on 11/5/25.
//

import Foundation
import SwiftUI
import Combine
import MusicKit

/// View model for playlist selection screen
/// Manages fetching and selecting user's Apple Music playlists
///
/// Python equivalent:
/// class PlaylistSelectionViewModel:
///     def __init__(self):
///         self.music_service = MusicService()
///         self.playlists = []
///         self.selected_playlist_ids = set()
///         self.is_loading = False
final class PlaylistSelectionViewModel: ObservableObject {
    
    // ═══════════════════════════════════════════════════════════
    // PUBLISHED PROPERTIES
    // ═══════════════════════════════════════════════════════════
    // MARK: - Published Properties
    
    /// List of user's playlists from Apple Music
    @Published var playlists: [MusicPlaylist] = []
    
    /// Set of selected playlist IDs
    @Published var selectedPlaylistIds: Set<String> = []
    
    /// Loading state while fetching playlists
    @Published var isLoading: Bool = false
    
    /// Error message if something goes wrong
    @Published var errorMessage: String?
    
    /// Estimated total tracks from selected playlists
    @Published var estimatedTrackCount: Int = 0
    
    // ═══════════════════════════════════════════════════════════
    // PRIVATE PROPERTIES
    // ═══════════════════════════════════════════════════════════
    // MARK: - Private Properties
    
    /// Music service for fetching playlists
    private let musicService = MusicService()
    
    /// Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    // ═══════════════════════════════════════════════════════════
    // INITIALIZATION
    // ═══════════════════════════════════════════════════════════
    // MARK: - Initialization
    
    init() {
        setupObservers()
    }
    
    // ═══════════════════════════════════════════════════════════
    // SETUP
    // ═══════════════════════════════════════════════════════════
    // MARK: - Setup
    
    /// Set up observers for music service
    private func setupObservers() {
        // Observe playlists from music service
        musicService.$userPlaylists
            .assign(to: &$playlists)
        
        // Observe loading state
        musicService.$isLoading
            .assign(to: &$isLoading)
        
        // Observe errors
        musicService.$error
            .compactMap { $0 }
            .sink { [weak self] error in
                self?.errorMessage = error.localizedDescription
            }
            .store(in: &cancellables)
    }
    
    // ═══════════════════════════════════════════════════════════
    // PUBLIC METHODS
    // ═══════════════════════════════════════════════════════════
    // MARK: - Public Methods
    
    /// Fetch user's playlists from Apple Music
    ///
    /// Python equivalent:
    /// def fetch_playlists(self):
    ///     self.is_loading = True
    ///     self.music_service.fetch_user_playlists(callback=self._on_playlists_fetched)
    func fetchPlaylists() {
        musicService.fetchUserPlaylists { [weak self] result in
            switch result {
            case .success(let playlists):
                print("✅ Fetched \(playlists.count) playlists")
            case .failure(let error):
                self?.errorMessage = "Failed to fetch playlists: \(error.localizedDescription)"
            }
        }
    }
    
    /// Toggle selection of a playlist
    ///
    /// - Parameter playlistId: ID of the playlist to toggle
    ///
    /// Python equivalent:
    /// def toggle_playlist_selection(self, playlist_id: str):
    ///     if playlist_id in self.selected_playlist_ids:
    ///         self.selected_playlist_ids.remove(playlist_id)
    ///     else:
    ///         self.selected_playlist_ids.add(playlist_id)
    ///     self._update_estimated_track_count()
    func togglePlaylistSelection(_ playlistId: String) {
        if selectedPlaylistIds.contains(playlistId) {
            selectedPlaylistIds.remove(playlistId)
        } else {
            selectedPlaylistIds.insert(playlistId)
        }
        
        updateEstimatedTrackCount()
    }
    
    /// Check if a playlist is selected
    ///
    /// - Parameter playlistId: ID of the playlist to check
    /// - Returns: True if playlist is selected
    func isPlaylistSelected(_ playlistId: String) -> Bool {
        return selectedPlaylistIds.contains(playlistId)
    }
    
    /// Get all tracks from selected playlists
    ///
    /// - Parameter completion: Called with array of tracks or error
    ///
    /// Python equivalent:
    /// def get_selected_tracks(self, callback: Callable[[List[Track]], None]):
    ///     all_tracks = []
    ///     for playlist_id in self.selected_playlist_ids:
    ///         tracks = self.music_service.fetch_tracks_from_playlist(playlist_id)
    ///         all_tracks.extend(tracks)
    ///     callback(all_tracks)
    func getSelectedTracks(completion: @escaping (Result<[Track], Error>) -> Void) {
        guard !selectedPlaylistIds.isEmpty else {
            completion(.failure(PlaylistSelectionError.noPlaylistsSelected))
            return
        }
        
        var allTracks: [Track] = []
        let group = DispatchGroup()
        var fetchError: Error?
        
        // Fetch tracks from each selected playlist
        for playlistId in selectedPlaylistIds {
            group.enter()
            
            musicService.fetchTracksFromPlaylist(playlistId: playlistId) { result in
                switch result {
                case .success(let tracks):
                    allTracks.append(contentsOf: tracks)
                case .failure(let error):
                    fetchError = error
                }
                group.leave()
            }
        }
        
        // Wait for all fetches to complete
        group.notify(queue: .main) {
            if let error = fetchError {
                completion(.failure(error))
            } else {
                completion(.success(allTracks))
            }
        }
    }
    
    // ═══════════════════════════════════════════════════════════
    // PRIVATE METHODS
    // ═══════════════════════════════════════════════════════════
    // MARK: - Private Methods
    
    /// Update estimated track count from selected playlists
    private func updateEstimatedTrackCount() {
        estimatedTrackCount = playlists
            .filter { selectedPlaylistIds.contains($0.id) }
            .reduce(0) { $0 + $1.trackCount }
    }
}

// ═══════════════════════════════════════════════════════════
// ERRORS
// ═══════════════════════════════════════════════════════════

/// Errors specific to playlist selection
enum PlaylistSelectionError: LocalizedError {
    case noPlaylistsSelected
    case noTracksFound
    
    var errorDescription: String? {
        switch self {
        case .noPlaylistsSelected:
            return "Please select at least one playlist"
        case .noTracksFound:
            return "No tracks found in selected playlists"
        }
    }
}
