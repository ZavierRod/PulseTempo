//
//  MusicService.swift
//  PulseTempo
//
//  Created by Zavier Rodrigues on 11/5/25.
//

import Foundation
import MusicKit
import Combine

protocol MusicServiceProtocol: AnyObject {
    var playbackStatePublisher: AnyPublisher<PlaybackState, Never> { get }
    var currentTrackPublisher: AnyPublisher<Track?, Never> { get }
    var errorPublisher: AnyPublisher<Error?, Never> { get }
    func play(track: Track, completion: @escaping (Result<Void, Error>) -> Void)
    func playQueue(tracks: [Track], startIndex: Int, completion: @escaping (Result<Void, Error>) -> Void)
    func playNext(track: Track)
    func pause()
    func resume()
    func stop()
    func fetchUserPlaylists(completion: @escaping (Result<[MusicPlaylist], Error>) -> Void)
    func fetchTracksFromPlaylist(playlistId: String, completion: @escaping (Result<[Track], Error>) -> Void)
}

/// Service for controlling Apple Music playback and managing the music queue
///
/// This ObservableObject manages all music playback operations including:
/// - Playing, pausing, and skipping tracks
/// - Managing the playback queue
/// - Fetching user playlists
/// - Searching for tracks by BPM
/// - Monitoring playback state
///
/// Usage:
/// ```swift
/// @StateObject private var musicService = MusicService()
///
/// musicService.play(track: someTrack) { result in
///     // Handle result
/// }
/// ```
final class MusicService: ObservableObject, MusicServiceProtocol {
    
    // MARK: - Published Properties
    
    /// The currently playing track
    /// SwiftUI views can observe this to update the UI when the track changes
    @Published var currentTrack: Track?
    
    /// Current playback state (playing, paused, stopped)
    @Published var playbackState: PlaybackState = .stopped
    
    /// Current playback time in seconds
    @Published var currentPlaybackTime: TimeInterval = 0
    
    /// Any error that occurred during music operations
    @Published var error: Error?
    
    /// List of user's playlists fetched from Apple Music
    @Published var userPlaylists: [MusicPlaylist] = []
    
    /// Whether we're currently loading data
    @Published var isLoading: Bool = false

    var playbackStatePublisher: AnyPublisher<PlaybackState, Never> {
        $playbackState.eraseToAnyPublisher()
    }

    var currentTrackPublisher: AnyPublisher<Track?, Never> {
        $currentTrack.eraseToAnyPublisher()
    }

    var errorPublisher: AnyPublisher<Error?, Never> {
        $error.eraseToAnyPublisher()
    }
    
    // MARK: - Private Properties
    
    /// Reference to the MusicKit authorization manager
    private let musicKitManager = MusicKitManager.shared
    
    /// The system music player instance
    /// This is the main interface for controlling playback
    private let player = ApplicationMusicPlayer.shared
    
    /// Queue of tracks to be played
    /// We maintain our own queue to have more control over track selection
    private var trackQueue: [Track] = []
    
    /// Set to track Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    /// Timer for updating playback time
    private var playbackTimer: Timer?
    
    // MARK: - Initialization
    
    init() {
        setupPlaybackObservers()
    }
    
    // MARK: - Playback Control
    
    /// Play a specific track
    ///
    /// This method will:
    /// 1. Check authorization
    /// 2. Convert our Track model to a MusicKit track
    /// 3. Set up the player queue
    /// 4. Begin playback
    ///
    /// - Parameters:
    ///   - track: The track to play
    ///   - completion: Called with success/failure result
    @MainActor
    func play(track: Track, completion: @escaping (Result<Void, Error>) -> Void) {
        // Ensure we have authorization
        guard musicKitManager.isAuthorized else {
            let error = MusicKitError.authorizationDenied
            self.error = error
            completion(.failure(error))
            return
        }
        
        Task {
            do {
                // Search for the track in Apple Music catalog
                // We need to convert our Track model to a MusicKit Song
                let musicTrack = try await searchForTrack(track)
                
                // Set the player queue with this track
                player.queue = ApplicationMusicPlayer.Queue(for: [musicTrack], startingAt: musicTrack)
                
                // Start playback
                try await player.play()
                
                // Update our state
                await MainActor.run {
                    self.currentTrack = track
                    self.playbackState = .playing
                    self.startPlaybackTimer()
                }
                
                completion(.success(()))
            } catch {
                await MainActor.run {
                    self.error = error
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Play a queue of tracks
    ///
    /// Use this when you want to queue up multiple tracks at once.
    /// The first track will start playing immediately.
    ///
    /// - Parameters:
    ///   - tracks: Array of tracks to play
    ///   - startIndex: Index of track to start with (default: 0)
    ///   - completion: Called with success/failure result
    @MainActor
    func playQueue(tracks: [Track], startIndex: Int = 0, completion: @escaping (Result<Void, Error>) -> Void) {
        guard musicKitManager.isAuthorized else {
            let error = MusicKitError.authorizationDenied
            self.error = error
            completion(.failure(error))
            return
        }
        
        guard !tracks.isEmpty, startIndex < tracks.count else {
            completion(.failure(MusicKitError.custom("Invalid track queue or start index")))
            return
        }
        
        Task {
            do {
                // Convert all tracks to MusicKit songs
                var musicTracks: [Song] = []
                for track in tracks {
                    let musicTrack = try await searchForTrack(track)
                    musicTracks.append(musicTrack)
                }
                
                // Set the player queue
                player.queue = ApplicationMusicPlayer.Queue(for: musicTracks, startingAt: musicTracks[startIndex])
                
                // Start playback
                try await player.play()
                
                // Update state
                await MainActor.run {
                    self.trackQueue = tracks
                    self.currentTrack = tracks[startIndex]
                    self.playbackState = .playing
                    self.startPlaybackTimer()
                }
                
                completion(.success(()))
            } catch {
                await MainActor.run {
                    self.error = error
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Pause playback
    ///
    /// Pauses the currently playing track. Call `resume()` to continue.
    @MainActor
    func pause() {
        Task {
            player.pause()
            await MainActor.run {
                self.playbackState = .paused
                self.stopPlaybackTimer()
            }
        }
    }
    
    /// Resume playback
    ///
    /// Resumes playback if it was paused
    @MainActor
    func resume() {
        Task {
            do {
                try await player.play()
                await MainActor.run {
                    self.playbackState = .playing
                    self.startPlaybackTimer()
                }
            } catch {
                await MainActor.run {
                    self.error = error
                }
            }
        }
    }
    
    /// Stop playback completely
    ///
    /// This stops playback and clears the queue
    @MainActor
    func stop() {
        Task {
            player.stop()
            await MainActor.run {
                self.playbackState = .stopped
                self.currentTrack = nil
                self.currentPlaybackTime = 0
                self.stopPlaybackTimer()
            }
        }
    }
    
    /// Skip to the next track in the queue
    ///
    /// If there's no next track, playback will stop
    @MainActor
    func skipToNext() {
        Task {
            do {
                try await player.skipToNextEntry()
                // The playback observer will update currentTrack
            } catch {
                await MainActor.run {
                    self.error = error
                }
            }
        }
    }
    
    /// Skip to the previous track in the queue
    @MainActor
    func skipToPrevious() {
        Task {
            do {
                try await player.skipToPreviousEntry()
                // The playback observer will update currentTrack
            } catch {
                await MainActor.run {
                    self.error = error
                }
            }
        }
    }
    
    /// Seek to a specific time in the current track
    ///
    /// - Parameter time: Time in seconds to seek to
    @MainActor
    func seek(to time: TimeInterval) {
        Task {
            // MusicKit uses playback time in seconds
            player.playbackTime = time
            await MainActor.run {
                self.currentPlaybackTime = time
            }
        }
    }
    
    // MARK: - Queue Management
    
    /// Add a track to the end of the current queue
    ///
    /// - Parameter track: Track to add to queue
    @MainActor
    func addToQueue(track: Track) {
        Task {
            do {
                let musicTrack = try await searchForTrack(track)
                
                // Insert at the end of the queue
                try await player.queue.insert(musicTrack, position: .tail)
                
                await MainActor.run {
                    self.trackQueue.append(track)
                }
            } catch {
                await MainActor.run {
                    self.error = error
                }
            }
        }
    }
    
    /// Insert a track to play next (after current track finishes)
    ///
    /// - Parameter track: Track to play next
    @MainActor
    func playNext(track: Track) {
        Task {
            do {
                let musicTrack = try await searchForTrack(track)
                
                // Insert after currently playing track
                try await player.queue.insert(musicTrack, position: .afterCurrentEntry)
                
                await MainActor.run {
                    // Insert after current track in our queue
                    if let currentIndex = self.trackQueue.firstIndex(where: { $0.id == self.currentTrack?.id }) {
                        self.trackQueue.insert(track, at: currentIndex + 1)
                    } else {
                        self.trackQueue.insert(track, at: 0)
                    }
                }
            } catch {
                await MainActor.run {
                    self.error = error
                }
            }
        }
    }
    
    /// Clear the entire playback queue
    @MainActor
    func clearQueue() {
        trackQueue.removeAll()
        // Note: MusicKit doesn't provide a direct way to clear the queue
        // We'd need to stop playback and start fresh
        stop()
    }
    
    // MARK: - Playlist Management
    
    /// Fetch the user's playlists from Apple Music
    ///
    /// This retrieves all playlists from the user's library.
    /// Results are stored in the `userPlaylists` published property.
    ///
    /// - Parameter completion: Called when fetch completes or fails
    @MainActor
    func fetchUserPlaylists(completion: @escaping (Result<[MusicPlaylist], Error>) -> Void) {
        guard musicKitManager.isAuthorized else {
            let error = MusicKitError.authorizationDenied
            self.error = error
            completion(.failure(error))
            return
        }
        
        Task {
            await MainActor.run {
                self.isLoading = true
            }
            
            do {
                // Request user's library playlists using Apple Music API
                let url = URL(string: "https://api.music.apple.com/v1/me/library/playlists?limit=100")!
                var request = MusicDataRequest(urlRequest: URLRequest(url: url))
                let response = try await request.response()
                
                // Decode the response
                let decoder = JSONDecoder()
                let playlistsResponse = try decoder.decode(LibraryPlaylistsResponse.self, from: response.data)
                
                // Convert to our MusicPlaylist model
                // Note: Track count is not available from the list API, would require individual fetches
                // which causes rate limiting. We'll show playlists without track counts for now.
                let playlistModels = playlistsResponse.data.map { playlist in
                    MusicPlaylist(
                        id: playlist.id,
                        name: playlist.attributes.name,
                        trackCount: 0,  // Track count not available from list endpoint
                        artwork: playlist.attributes.artwork
                    )
                }
                
                await MainActor.run {
                    self.userPlaylists = playlistModels
                    self.isLoading = false
                }
                
                completion(.success(playlistModels))
            } catch {
                await MainActor.run {
                    self.error = error
                    self.isLoading = false
                }
                completion(.failure(error))
            }
        }
    }
    
    /// Fetch tracks from a specific playlist
    ///
    /// - Parameters:
    ///   - playlistId: The ID of the playlist
    ///   - completion: Called with array of tracks or error
    @MainActor
    func fetchTracksFromPlaylist(playlistId: String, completion: @escaping (Result<[Track], Error>) -> Void) {
        guard musicKitManager.isAuthorized else {
            let error = MusicKitError.authorizationDenied
            self.error = error
            completion(.failure(error))
            return
        }
        
        Task {
            do {
                // Request tracks from the specific library playlist
                let url = URL(string: "https://api.music.apple.com/v1/me/library/playlists/\(playlistId)/tracks")!
                var request = MusicDataRequest(urlRequest: URLRequest(url: url))
                let response = try await request.response()
                
                // Decode the response
                let decoder = JSONDecoder()
                let tracksResponse = try decoder.decode(LibraryTracksResponse.self, from: response.data)
                
                // Convert to our Track model
                let tracks = tracksResponse.data.map { track in
                    Track(
                        id: track.id,
                        title: track.attributes.name,
                        artist: track.attributes.artistName,
                        durationSeconds: Int(track.attributes.durationInMillis / 1000),
                        bpm: nil // BPM will be fetched from backend later
                    )
                }
                
                completion(.success(tracks))
            } catch {
                await MainActor.run {
                    self.error = error
                }
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Search
    
    /// Search for a track in the Apple Music catalog
    ///
    /// This is used internally to convert our Track model to a MusicKit Song
    /// that can be played by the ApplicationMusicPlayer.
    ///
    /// - Parameter track: Our Track model to search for
    /// - Returns: MusicKit Song object
    /// - Throws: Error if track not found or search fails
    private func searchForTrack(_ track: Track) async throws -> Song {
        // Create a search request for the track
        // We search by title and artist for best match
        let searchTerm = "\(track.title) \(track.artist)"
        
        var request = MusicCatalogSearchRequest(term: searchTerm, types: [Song.self])
        request.limit = 5 // Get top 5 results
        
        let response = try await request.response()
        
        // Try to find the best match
        // Ideally we'd use the track ID if we have it from Apple Music
        guard let song = response.songs.first else {
            throw MusicKitError.itemNotFound
        }
        
        return song
    }
    
    // MARK: - Playback Observers
    
    /// Set up observers for playback state changes
    ///
    /// This monitors the ApplicationMusicPlayer for state changes and
    /// updates our published properties accordingly.
    private func setupPlaybackObservers() {
        // Observe playback state changes
        player.state.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.updatePlaybackState()
                }
            }
            .store(in: &cancellables)
        
        // Observe queue changes
        player.queue.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.updateCurrentTrack()
                }
            }
            .store(in: &cancellables)
    }
    
    /// Update playback state based on player state
    @MainActor
    private func updatePlaybackState() {
        switch player.state.playbackStatus {
        case .playing:
            playbackState = .playing
            startPlaybackTimer()
        case .paused:
            playbackState = .paused
            stopPlaybackTimer()
        case .stopped:
            playbackState = .stopped
            stopPlaybackTimer()
        case .interrupted:
            playbackState = .paused
            stopPlaybackTimer()
        case .seekingForward, .seekingBackward:
            // Keep current state during seeking
            break
        @unknown default:
            break
        }
    }
    
    /// Update current track based on player queue
    @MainActor
    private func updateCurrentTrack() {
        if let currentEntry = player.queue.currentEntry, let item = currentEntry.item {
            switch item {
            case .song(let song):
                // Try to find matching track in our queue
                if let matchingTrack = trackQueue.first(where: { $0.id == song.id.rawValue }) {
                    currentTrack = matchingTrack
                } else {
                    // Create a new track from the song
                    currentTrack = Track(
                        id: song.id.rawValue,
                        title: song.title,
                        artist: song.artistName,
                        durationSeconds: Int(song.duration ?? 0),
                        bpm: nil
                    )
                }
            default:
                break
            }
        }
    }
    
    // MARK: - Playback Timer
    
    private func startPlaybackTimer() {
        stopPlaybackTimer() // Stop existing timer if any

        // Use selector-based timer to avoid capturing `self` in a @Sendable closure
        playbackTimer = Timer.scheduledTimer(timeInterval: 0.5,
                                             target: self,
                                             selector: #selector(handlePlaybackTimer),
                                             userInfo: nil,
                                             repeats: true)
    }
    
    @MainActor
    @objc private func handlePlaybackTimer() {
        currentPlaybackTime = player.playbackTime
    }
    
    /// Stop the playback timer
    private func stopPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
    
    // MARK: - Cleanup
    
    deinit {
        stopPlaybackTimer()
        cancellables.removeAll()
    }
}

// MARK: - Supporting Types

/// Playback state enumeration
enum PlaybackState {
    case playing
    case paused
    case stopped
}

/// Simplified playlist model for UI display
struct MusicPlaylist: Identifiable, Equatable {
    let id: String
    let name: String
    let trackCount: Int
    let artwork: Artwork?
}

// MARK: - Apple Music API Response Models

/// Response structure for library playlists from Apple Music API
private struct LibraryPlaylistsResponse: Codable {
    let data: [LibraryPlaylistItem]
}

/// Response structure for a single library playlist
private struct SingleLibraryPlaylistResponse: Codable {
    let data: LibraryPlaylistItem
}

private struct LibraryPlaylistItem: Codable {
    let id: String
    let attributes: LibraryPlaylistAttributes
    let relationships: LibraryPlaylistRelationships?
}

private struct LibraryPlaylistAttributes: Codable {
    let name: String
    let artwork: Artwork?
}

private struct LibraryPlaylistRelationships: Codable {
    let tracks: TracksRelationship?
}

private struct TracksRelationship: Codable {
    let data: [TrackReference]?
}

private struct TrackReference: Codable {
    let id: String
}

/// Response structure for library tracks from Apple Music API
private struct LibraryTracksResponse: Codable {
    let data: [LibraryTrackItem]
}

private struct LibraryTrackItem: Codable {
    let id: String
    let attributes: LibraryTrackAttributes
}

private struct LibraryTrackAttributes: Codable {
    let name: String
    let artistName: String
    let durationInMillis: Int
}

// MARK: - Preview Helper

#if DEBUG
extension MusicService {
    /// Simulate playback for preview/testing purposes
    func simulatePlayback(track: Track) {
        currentTrack = track
        playbackState = .playing
    }
}
#endif

