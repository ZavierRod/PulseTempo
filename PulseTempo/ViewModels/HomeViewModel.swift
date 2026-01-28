//
//  HomeViewModel.swift
//  PulseTempo
//
//  Created by Zavier Rodrigues on 11/17/25.
//

import Foundation
import SwiftUI
import Combine

/// View model for the home screen dashboard
/// Manages selected playlists, workout stats, and navigation state
final class HomeViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Selected playlists for workouts
    @Published var selectedPlaylists: [MusicPlaylist] = []
    
    /// Total track count from selected playlists
    @Published var totalTrackCount: Int = 0
    
    /// Last workout summary (if available)
    @Published var lastWorkout: WorkoutSummary?
    
    /// Loading state
    @Published var isLoading: Bool = false
    
    /// Error message if something goes wrong
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    
    /// Music service for fetching playlists
    private let musicService: MusicServiceProtocol

    /// Playlist storage manager
    private let storageManager: PlaylistStorageManaging
    
    /// Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(musicService: MusicServiceProtocol = MusicService.shared, storageManager: PlaylistStorageManaging = PlaylistStorageManager.shared) {
        self.musicService = musicService
        self.storageManager = storageManager
        loadSelectedPlaylists()
        loadLastWorkout()
    }
    
    // MARK: - Public Methods
    
    /// Refresh playlist data from storage
    func refreshPlaylists() {
        loadSelectedPlaylists()
    }
    
    /// Load selected playlists from UserDefaults
    private func loadSelectedPlaylists() {
        // Load saved playlist IDs from storage
        let savedPlaylistIds = storageManager.loadSelectedPlaylists()
        
        // If no saved playlists, show empty state
        guard !savedPlaylistIds.isEmpty else {
            selectedPlaylists = []
            totalTrackCount = 0
            return
        }
        
        isLoading = true
        
        // Fetch all user playlists from Apple Music
        musicService.fetchUserPlaylists { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(let allPlaylists):
                    // Filter to only show playlists that were saved
                    let savedSet = Set(savedPlaylistIds)
                    self?.selectedPlaylists = allPlaylists.filter { savedSet.contains($0.id) }
                    self?.calculateTotalTracks()
                    
                    print("📱 Loaded \(self?.selectedPlaylists.count ?? 0) selected playlists for HomeView")
                    
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    /// Calculate total track count from selected playlists
    private func calculateTotalTracks() {
        totalTrackCount = selectedPlaylists.reduce(0) { $0 + $1.trackCount }
    }
    
    /// Load last workout summary
    private func loadLastWorkout() {
        // TODO: Load from persistent storage
        // Placeholder for now
        lastWorkout = nil
    }
    
    /// Save selected playlists to storage
    func saveSelectedPlaylists(_ playlistIds: [String]) {
        storageManager.saveSelectedPlaylists(playlistIds)
        // Refresh to show updated selections
        refreshPlaylists()
    }
    
    /// Fetch all tracks from selected playlists for workout
    func fetchTracksForWorkout(completion: @escaping (Result<[Track], Error>) -> Void) {
        let savedPlaylistIds = storageManager.loadSelectedPlaylists()
        
        guard !savedPlaylistIds.isEmpty else {
            completion(.failure(NSError(
                domain: "HomeViewModel",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "No playlists selected"]
            )))
            return
        }
        
        var allTracks: [Track] = []
        let group = DispatchGroup()
        var fetchError: Error?
        
        // Fetch tracks from each selected playlist WITHOUT triggering BPM analysis
        // BPM analysis should only happen during playlist selection, not workout start
        for playlistId in savedPlaylistIds {
            group.enter()
            
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
        
        // Wait for all fetches to complete
        group.notify(queue: .main) {
            if let error = fetchError {
                completion(.failure(error))
            } else {
                print("🎵 Fetched \(allTracks.count) tracks for workout")
                completion(.success(allTracks))
            }
        }
    }
}

// MARK: - Workout Summary Model

/// Summary of a completed workout
struct WorkoutSummary: Identifiable {
    let id: String
    let date: Date
    let durationMinutes: Int
    let averageBPM: Int
    let songsPlayed: Int
    
    /// Formatted date string
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    /// Formatted duration string
    var formattedDuration: String {
        if durationMinutes < 60 {
            return "\(durationMinutes) min"
        } else {
            let hours = durationMinutes / 60
            let minutes = durationMinutes % 60
            return "\(hours)h \(minutes)m"
        }
    }
}
