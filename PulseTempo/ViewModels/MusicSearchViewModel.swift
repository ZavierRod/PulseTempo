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
    
    /// Full Track objects that were successfully added (for optimistic UI updates)
    @Published var addedTracks: [Track] = []
    
    // MARK: - Private Properties
    
    /// The playlist ID to add songs to
    let playlistId: String
    
    /// Music service for API calls
    private let musicService = MusicService.shared
    
    /// Preview URLs keyed by track ID (captured during search, used for BPM analysis)
    private var previewURLs: [String: String] = [:]
    
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
                let result = try await musicService.searchCatalog(query: query)
                self.searchResults = result.tracks
                self.previewURLs.merge(result.previewURLs) { _, new in new }
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
        guard !addedTrackIds.contains(track.id) else {
            print("⚠️ [MusicSearch] Track already added: \(track.id)")
            return
        }
        
        print("🎵 [MusicSearch] Adding '\(track.title)' by \(track.artist)")
        print("🎵 [MusicSearch] Track ID: \(track.id) → Playlist ID: \(playlistId)")
        
        isAdding = true
        errorMessage = nil
        
        Task { @MainActor in
            do {
                try await musicService.addTrackToPlaylist(trackId: track.id, playlistId: playlistId)
                self.addedTrackIds.insert(track.id)
                self.addedTracks.append(track)
                self.isAdding = false
                print("🎵 [MusicSearch] UI updated — checkmark shown for '\(track.title)'")
                
                // Trigger BPM analysis immediately so the track has BPM data for workouts
                if let previewUrl = self.previewURLs[track.id] {
                    print("🔍 [MusicSearch] Triggering BPM analysis for '\(track.title)'")
                    Task {
                        await musicService.analyzeTrackBPM(track: track, previewUrl: previewUrl)
                        // Update the addedTracks entry with the new BPM from cache
                        await MainActor.run {
                            if let bpm = UserDefaults.standard.dictionary(forKey: "com.pulsetempo.bpmCache")?[track.id] as? Int,
                               let index = self.addedTracks.firstIndex(where: { $0.id == track.id }) {
                                self.addedTracks[index] = Track(
                                    id: track.id, title: track.title, artist: track.artist,
                                    durationSeconds: track.durationSeconds, bpm: bpm, artworkURL: track.artworkURL
                                )
                                print("✅ [MusicSearch] BPM updated for '\(track.title)': \(bpm)")
                            }
                        }
                    }
                } else {
                    print("⚠️ [MusicSearch] No preview URL for '\(track.title)' — BPM analysis skipped")
                }
            } catch {
                let errorMsg = "Failed to add song: \(error.localizedDescription)"
                self.errorMessage = errorMsg
                self.isAdding = false
                print("🎵 [MusicSearch] UI error shown: \(errorMsg)")
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
