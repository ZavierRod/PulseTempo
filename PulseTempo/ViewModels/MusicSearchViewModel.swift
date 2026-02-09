//
//  MusicSearchViewModel.swift
//  PulseTempo
//
//  Created by Zavier Rodrigues on 2/9/26.
//

import Foundation
import Combine

/// View model for searching the Apple Music catalog and adding songs to playlists
///
/// Handles debounced search queries, loading states, and track-to-playlist additions.
/// Follows the same patterns as PlaylistSelectionViewModel.
final class MusicSearchViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Current search query text
    @Published var searchQuery: String = ""
    
    /// Search results from the Apple Music catalog
    @Published var searchResults: [Track] = []
    
    /// Whether a search is in progress
    @Published var isSearching: Bool = false
    
    /// Whether a track is being added to a playlist
    @Published var isAdding: Bool = false
    
    /// Error message to display
    @Published var errorMessage: String?
    
    /// Set of track IDs that were successfully added (for UI feedback)
    @Published var addedTrackIds: Set<String> = []
    
    // MARK: - Private Properties
    
    /// The playlist ID to add songs to
    let playlistId: String
    
    /// Music service for API calls
    private let musicService = MusicService.shared
    
    /// Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(playlistId: String) {
        self.playlistId = playlistId
        setupSearchDebounce()
    }
    
    // MARK: - Setup
    
    /// Set up debounced search — waits 300ms after user stops typing before searching
    private func setupSearchDebounce() {
        $searchQuery
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] query in
                guard let self = self else { return }
                let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    self.searchResults = []
                    self.errorMessage = nil
                } else {
                    self.performSearch(query: trimmed)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Search
    
    /// Perform a catalog search
    private func performSearch(query: String) {
        isSearching = true
        errorMessage = nil
        
        Task { @MainActor in
            do {
                let results = try await musicService.searchCatalog(query: query)
                self.searchResults = results
                self.isSearching = false
            } catch {
                self.errorMessage = "Search failed: \(error.localizedDescription)"
                self.isSearching = false
            }
        }
    }
    
    // MARK: - Add to Playlist
    
    /// Add a track to the target playlist
    ///
    /// - Parameter track: The catalog track to add
    func addTrack(_ track: Track) {
        guard !addedTrackIds.contains(track.id) else { return }
        
        isAdding = true
        errorMessage = nil
        
        Task { @MainActor in
            do {
                try await musicService.addTrackToPlaylist(trackId: track.id, playlistId: playlistId)
                self.addedTrackIds.insert(track.id)
                self.isAdding = false
            } catch {
                self.errorMessage = "Failed to add song: \(error.localizedDescription)"
                self.isAdding = false
            }
        }
    }
    
    /// Clear search state
    func clearSearch() {
        searchQuery = ""
        searchResults = []
        errorMessage = nil
    }
}
