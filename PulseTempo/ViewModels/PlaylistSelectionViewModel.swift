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
    
    /// Whether BPM analysis is currently in progress
    @Published var isAnalyzing: Bool = false
    
    /// Tracks fetched from selected playlists (stored until analysis completes)
    @Published var fetchedTracks: [Track] = []
    
    // ═══════════════════════════════════════════════════════════
    // PRIVATE PROPERTIES
    // ═══════════════════════════════════════════════════════════
    // MARK: - Private Properties
    
    /// Music service for fetching playlists
    private let musicService = MusicService.shared
    
    /// Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    /// Callback to invoke when analysis completes
    private var analysisCompletionCallback: ((Result<[Track], Error>) -> Void)?
    
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
            
        // Observe analysis status and trigger completion callback when done
        musicService.$analyzingTrackCount
            .receive(on: DispatchQueue.main)
            .sink { [weak self] count in
                guard let self = self else { return }
                let wasAnalyzing = self.isAnalyzing
                self.isAnalyzing = count > 0
                
                // If analysis just completed and we have a pending callback, re-fetch tracks with cached BPM
                if wasAnalyzing && !self.isAnalyzing, let callback = self.analysisCompletionCallback {
                    self.analysisCompletionCallback = nil
                    
                    // Re-fetch tracks to get updated BPM values from cache
                    // The original fetchedTracks don't have BPM because they were created before analysis
                    print("✅ BPM analysis complete - re-fetching tracks with cached BPM values")
                    self.refetchTracksWithCachedBPM(completion: callback)
                }
            }
            .store(in: &cancellables)
    }
    
    /// Re-fetch tracks from selected playlists to get updated BPM values from cache
    /// Called after BPM analysis completes to ensure tracks have their BPM values
    private func refetchTracksWithCachedBPM(completion: @escaping (Result<[Track], Error>) -> Void) {
        var allTracks: [Track] = []
        let group = DispatchGroup()
        var fetchError: Error?
        
        for playlistId in selectedPlaylistIds {
            group.enter()
            
            // Fetch WITHOUT triggering analysis - just use cached values
            musicService.fetchTracksFromPlaylist(playlistId: playlistId, triggerBPMAnalysis: false) { result in
                switch result {
                case .success(let tracks):
                    allTracks.append(contentsOf: tracks)
                case .failure(let error):
                    fetchError = error
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) { [weak self] in
            if let error = fetchError {
                completion(.failure(error))
            } else {
                self?.fetchedTracks = allTracks
                let tracksWithBPM = allTracks.filter { $0.bpm != nil }.count
                print("📊 Re-fetched \(allTracks.count) tracks, \(tracksWithBPM) have BPM")
                completion(.success(allTracks))
            }
        }
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
    
    /// Get all tracks from selected playlists and wait for BPM analysis to complete
    ///
    /// - Parameter completion: Called with array of tracks AFTER BPM analysis is done
    ///
    /// This method:
    /// 1. Fetches tracks from all selected playlists
    /// 2. Triggers BPM analysis for tracks that don't have cached BPM
    /// 3. Waits for ALL analysis to complete before calling completion
    /// 4. The completion callback receives tracks with updated BPM values
    func getSelectedTracks(completion: @escaping (Result<[Track], Error>) -> Void) {
        guard !selectedPlaylistIds.isEmpty else {
            completion(.failure(PlaylistSelectionError.noPlaylistsSelected))
            return
        }
        
        var allTracks: [Track] = []
        let group = DispatchGroup()
        var fetchError: Error?
        
        // Fetch tracks from each selected playlist with BPM analysis enabled
        for playlistId in selectedPlaylistIds {
            group.enter()
            
            musicService.fetchTracksFromPlaylist(playlistId: playlistId, triggerBPMAnalysis: true) { result in
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
        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            
            if let error = fetchError {
                completion(.failure(error))
                return
            }
            
            // Store fetched tracks
            self.fetchedTracks = allTracks
            
            // If no analysis is happening (all tracks already cached), complete immediately
            if !self.isAnalyzing {
                print("✅ All tracks already have BPM cached - completing immediately")
                completion(.success(allTracks))
            } else {
                // Store callback to invoke when analysis completes
                print("⏳ Waiting for BPM analysis to complete...")
                self.analysisCompletionCallback = completion
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
