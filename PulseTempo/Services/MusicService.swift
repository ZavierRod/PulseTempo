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
    var currentPlaybackTimePublisher: AnyPublisher<TimeInterval, Never> { get }

    var errorPublisher: AnyPublisher<Error?, Never> { get }
    var trackUpdatedPublisher: AnyPublisher<Track, Never> { get }
    func play(track: Track, completion: @escaping (Result<Void, Error>) -> Void)
    func playQueue(tracks: [Track], startIndex: Int, completion: @escaping (Result<Void, Error>) -> Void)
    func playNext(track: Track)
    func replaceNext(track: Track)
    func pause()
    func resume()
    func stop()
    func fetchUserPlaylists(completion: @escaping (Result<[MusicPlaylist], Error>) -> Void)
    func fetchTracksFromPlaylist(playlistId: String, triggerBPMAnalysis: Bool, completion: @escaping (Result<[Track], Error>) -> Void)
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
class MusicService: ObservableObject, MusicServiceProtocol {
    
    /// Shared singleton instance
    static let shared = MusicService()
    
    // MARK: - Published Properties
    
    /// The currently playing track
    /// SwiftUI views can observe this to update the UI when the track changes
    @Published var currentTrack: Track?
    
    /// Number of tracks currently being analyzed for BPM
    @Published var analyzingTrackCount: Int = 0
    
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
    
    /// Subject for broadcasting track updates (e.g. BPM analysis results)
    private let trackUpdatedSubject = PassthroughSubject<Track, Never>()
    
    var playbackStatePublisher: AnyPublisher<PlaybackState, Never> {
        $playbackState.eraseToAnyPublisher()
    }

    var currentTrackPublisher: AnyPublisher<Track?, Never> {
        $currentTrack.eraseToAnyPublisher()
    }

    var errorPublisher: AnyPublisher<Error?, Never> {
        $error.eraseToAnyPublisher()
    }
    
    var currentPlaybackTimePublisher: AnyPublisher<TimeInterval, Never> {
        $currentPlaybackTime.eraseToAnyPublisher()
    }
    
    var trackUpdatedPublisher: AnyPublisher<Track, Never> {
        trackUpdatedSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Private Properties
    
    /// Reference to the MusicKit authorization manager
    internal let musicKitManager: MusicKitManager
    
    /// The system music player instance
    /// This is the main interface for controlling playback
    internal let player: ApplicationMusicPlayer
    
    /// Queue of tracks to be played
    /// We maintain our own queue to have more control over track selection
    internal var trackQueue: [Track] = []
    
    /// Cached catalog Song for the currently playing track
    /// This is needed because queue rebuilding requires the original Song object,
    /// not one extracted from currentEntry (which causes MPMusicPlayerControllerErrorDomain error 6)
    private var currentCatalogSong: Song?
    
    /// Timestamp when playback started - used to delay queue modifications
    /// MusicKit needs time to establish the queue before accepting insert operations
    private var playbackStartTime: Date?
    
    /// Minimum delay after playback starts before queue modifications are allowed (in seconds)
    private let queueReadyDelay: TimeInterval = 2.0
    
    /// Track the last song ID we logged to prevent duplicate "NOW PLAYING" logs
    private var lastLoggedSongId: String?
    
    /// Cache of analyzed BPM values by track ID (persists across fetches AND app restarts)
    /// Key: track ID (e.g., "i.ABC123") or "title|artist", Value: analyzed BPM
    /// Stored in UserDefaults for persistence
    private var bpmCache: [String: Int] = [:] {
        didSet {
            saveBPMCacheToDisk()
        }
    }
    
    /// UserDefaults key for BPM cache persistence
    private static let bpmCacheKey = "com.pulsetempo.bpmCache"
    
    /// Semaphore to limit concurrent BPM analysis requests (avoids overwhelming backend)
    private let bpmAnalysisSemaphore = AsyncSemaphore(limit: 4)
    
    /// Set to track Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    /// Timer for updating playback time
    private var playbackTimer: Timer?
    
    // MARK: - Initialization
    
    init(musicKitManager: MusicKitManager = .shared, player: ApplicationMusicPlayer = .shared) {
        self.musicKitManager = musicKitManager
        self.player = player
        loadBPMCacheFromDisk()
        setupPlaybackObservers()
    }
    
    // MARK: - Local Network Permission
    
    /// Triggers a simple network request to prompt the user for local network permission early.
    /// This should be called during app initialization to ensure permission is granted
    /// before BPM analysis is attempted.
    func warmUpLocalNetworkPermission() {
        // Use Railway production backend
        let host = "https://pulsetempo-production.up.railway.app"
        
        guard let url = URL(string: "\(host)/api/health") else {
            // Fallback: try the analyze endpoint with a simple GET (will fail but triggers permission)
            guard let fallbackUrl = URL(string: "\(host)/api/tracks/analyze") else { return }
            URLSession.shared.dataTask(with: fallbackUrl) { _, _, _ in
                print("🌐 Local network permission warm-up request sent (fallback)")
            }.resume()
            return
        }
        
        // Make a simple request to trigger the local network permission dialog
        URLSession.shared.dataTask(with: url) { _, _, error in
            if let error = error {
                print("🌐 Local network warm-up failed (this is expected if backend is not running): \(error.localizedDescription)")
            } else {
                print("✅ Local network permission granted and backend is reachable")
            }
        }.resume()
        
        print("🌐 Local network permission warm-up request sent")
    }
    
    // MARK: - BPM Cache Persistence
    
    /// Load BPM cache from UserDefaults on app launch
    /// This ensures we never re-analyze songs that have already been processed
    private func loadBPMCacheFromDisk() {
        if let savedCache = UserDefaults.standard.dictionary(forKey: Self.bpmCacheKey) as? [String: Int] {
            bpmCache = savedCache
            print("📦 Loaded \(savedCache.count) cached BPM values from disk")
        } else {
            print("📦 No cached BPM values found on disk")
        }
    }
    
    /// Save BPM cache to UserDefaults for persistence across app restarts
    private func saveBPMCacheToDisk() {
        UserDefaults.standard.set(bpmCache, forKey: Self.bpmCacheKey)
        // Don't print every save to avoid log spam - the didSet triggers on every change
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
        
        print("🎵 Starting play for: '\(track.title)' by \(track.artist)")
        
        Task {
            do {
                // Set trackQueue BEFORE playback so updateCurrentTrack() can match
                await MainActor.run {
                    // Add to queue if not already present (match by title+artist since IDs differ)
                    let existingIndex = self.trackQueue.firstIndex(where: { 
                        $0.id == track.id || 
                        ($0.title.lowercased() == track.title.lowercased() && $0.artist.lowercased() == track.artist.lowercased()) 
                    })
                    
                    if let index = existingIndex {
                        // Update existing track with latest data (e.g., BPM)
                        self.trackQueue[index] = track
                    } else {
                        // Add new track
                        self.trackQueue.append(track)
                    }
                    print("📋 Track queue updated: '\(track.title)' (BPM: \(track.bpm?.description ?? "nil")) | Queue size: \(self.trackQueue.count)")
                }
                
                // Search for the track in Apple Music catalog
                // We need to convert our Track model to a MusicKit Song
                print("🔍 Searching catalog for: '\(track.title)'")
                let musicTrack = try await searchForTrack(track)
                print("✅ Catalog search successful, creating queue...")
                
                // Set the player queue with this track
                player.queue = ApplicationMusicPlayer.Queue(for: [musicTrack], startingAt: musicTrack)
                print("✅ Queue created, attempting playback...")
                
                // Start playback
                try await player.play()
                print("✅ Playback started successfully")
                
                // Update our state
                // NOTE: Don't set currentTrack here - let updateCurrentTrack() handle it
                // via the queue observer to prevent duplicate publisher emissions
                await MainActor.run {
                    self.currentCatalogSong = musicTrack  // Cache for queue operations
                    self.playbackStartTime = Date()       // Mark when playback started
                    self.playbackState = .playing
                    self.startPlaybackTimer()
                }
                
                completion(.success(()))
            } catch {
                print("❌ Play failed: \(error.localizedDescription)")
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
                
                // Set trackQueue BEFORE playback starts so updateCurrentTrack() can match
                await MainActor.run {
                    self.trackQueue = tracks
                }
                
                // Set the player queue
                player.queue = ApplicationMusicPlayer.Queue(for: musicTracks, startingAt: musicTracks[startIndex])
                
                // Start playback
                try await player.play()
                
                // Update remaining state after playback starts
                // NOTE: Don't set currentTrack here - let updateCurrentTrack() handle it
                // via the queue observer to prevent duplicate publisher emissions
                await MainActor.run {
                    self.currentCatalogSong = musicTracks[startIndex]  // Cache for queue operations
                    self.playbackStartTime = Date()                    // Mark when playback started
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
                self.currentCatalogSong = nil    // Clear cached song
                self.playbackStartTime = nil     // Clear playback timing
                self.lastLoggedSongId = nil      // Reset for next session
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
    
    /// Replace the next queued track (ensures queue size of 1)
    ///
    /// This method ensures only ONE track is queued after the current playing track.
    /// It clears any previously queued tracks and queues the new one.
    /// Use this for dynamic HR-based track selection during workouts.
    ///
    /// **Implementation Note:**
    /// MusicKit's Queue API is limited - there's no way to remove specific entries.
    /// We use `insert(_, position: .afterCurrentEntry)` which effectively "replaces"
    /// the next track since the player will play the most recently inserted track next.
    /// 
    /// **Why not rebuild the queue?**
    /// Rebuilding the queue during active playback with `startingAt:` causes
    /// MPMusicPlayerControllerErrorDomain error 6 ("Prepare queue failed with unexpected start item")
    /// because the Song object from currentEntry is not the same reference MusicKit expects.
    ///
    /// - Parameter track: Track to queue as the next track
    @MainActor
    func replaceNext(track: Track) {
        Task {
            do {
                // Check if queue is ready for modifications
                // MusicKit needs time to establish the queue after play() is called
                if let startTime = self.playbackStartTime {
                    let elapsed = Date().timeIntervalSince(startTime)
                    if elapsed < queueReadyDelay {
                        let waitTime = queueReadyDelay - elapsed
                        print("⏳ Waiting \(String(format: "%.1f", waitTime))s for queue to be ready...")
                        try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
                    }
                }
                
                // Validate we can find the track in Apple Music before attempting queue operations
                let musicTrack = try await searchForTrack(track)
                
                // Check if we have an active playback
                let isPlaying = self.playbackState == .playing || self.playbackState == .paused
                
                // Get current track name for logging
                let currentTrackName = self.currentTrack?.title ?? "Unknown"
                
                if isPlaying, self.currentCatalogSong != nil {
                    // ACTIVE PLAYBACK: Use insert instead of queue rebuild
                    // This avoids the "Prepare queue failed with unexpected start item" error
                    // Note: MusicKit will play the most recently inserted track next
                    try await player.queue.insert(musicTrack, position: .afterCurrentEntry)
                    print("🎵 Inserted next track after current entry | Playing: '\(currentTrackName)'")
                } else if let cachedSong = self.currentCatalogSong {
                    // STOPPED: Safe to rebuild queue since nothing is playing
                    // Store current playback time to restore position
                    let currentPlaybackTime = player.playbackTime
                    
                    // Verify both songs have valid identifiers before rebuilding
                    guard !cachedSong.id.rawValue.isEmpty,
                          !musicTrack.id.rawValue.isEmpty else {
                        print("⚠️ Skipping queue rebuild - invalid track identifiers")
                        return
                    }
                    
                    // Create new queue with only current + new next track using cached Song
                    player.queue = ApplicationMusicPlayer.Queue(
                        for: [cachedSong, musicTrack],
                        startingAt: cachedSong
                    )
                    
                    // Restore playback position
                    player.playbackTime = currentPlaybackTime
                    
                    print("♻️ Rebuilt queue: Current + 1 next track (size=2, queued=1)")
                } else {
                    // No cached song - insert after current entry
                    print("ℹ️ No cached song, inserting after current entry")
                    try await player.queue.insert(musicTrack, position: .afterCurrentEntry)
                }
                
                await MainActor.run {
                    // Update our internal queue - keep only current track + new next
                    if let currentTrack = self.currentTrack {
                        self.trackQueue = [currentTrack, track]
                    } else {
                        self.trackQueue = [track]
                    }
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    print("❌ Error replacing next track: \(error.localizedDescription)")
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
    ///   - triggerBPMAnalysis: Whether to trigger BPM analysis for tracks without cached BPM.
    ///                         Set to `true` when selecting playlists, `false` when starting workouts.
    ///   - completion: Called with array of tracks or error
    @MainActor
    func fetchTracksFromPlaylist(playlistId: String, triggerBPMAnalysis: Bool = false, completion: @escaping (Result<[Track], Error>) -> Void) {
        guard musicKitManager.isAuthorized else {
            let error = MusicKitError.authorizationDenied
            self.error = error
            completion(.failure(error))
            return
        }
        
        Task {
            do {
                // Request tracks from the specific library playlist
                // Include catalog relationship to get preview URLs
                let url = URL(string: "https://api.music.apple.com/v1/me/library/playlists/\(playlistId)/tracks?include=catalog")!
                var request = MusicDataRequest(urlRequest: URLRequest(url: url))
                let response = try await request.response()
                
                // Decode the response
                let decoder = JSONDecoder()
                let tracksResponse = try decoder.decode(LibraryTracksResponse.self, from: response.data)
                
                // Convert to our Track model
                // Use cached BPM if available, otherwise nil (will be populated by backend analysis)
                let tracks = tracksResponse.data.map { track in
                    // Try to find cached BPM by ID first, then by title+artist
                    var cachedBPM = self.bpmCache[track.id]
                    if cachedBPM == nil {
                        let titleArtistKey = "\(track.attributes.name.lowercased())|\(track.attributes.artistName.lowercased())"
                        cachedBPM = self.bpmCache[titleArtistKey]
                    }
                    if cachedBPM != nil {
                        print("📦 Using cached BPM for '\(track.attributes.name)': \(cachedBPM!)")
                    }
                    // Extract artwork URL from track attributes
                    let artworkURL = track.attributes.artwork?.url(width: 120, height: 120)
                    
                    return Track(
                        id: track.id,
                        title: track.attributes.name,
                        artist: track.attributes.artistName,
                        durationSeconds: Int(track.attributes.durationInMillis / 1000),
                        bpm: cachedBPM,  // Use cached BPM if available
                        artworkURL: artworkURL
                    )
                }
                
                // Only trigger BPM analysis if requested (during playlist confirmation)
                // BPM values are cached to disk so songs never need re-analysis
                // When triggerBPMAnalysis=false (e.g., starting workout), we use cached values only
                let tracksWithCachedBPM = tracks.filter { $0.bpm != nil }.count
                print("📊 Tracks status: \(tracksWithCachedBPM)/\(tracks.count) have cached BPM")
                
                if triggerBPMAnalysis {
                    let tracksNeedingAnalysis = tracks.filter { $0.bpm == nil }
                    if tracksNeedingAnalysis.isEmpty {
                        print("✅ All tracks already have BPM cached")
                    } else {
                        print("🔍 Triggering BPM analysis for \(tracksNeedingAnalysis.count) tracks...")
                        
                        // Collect tracks with preview URLs
                        var analysisItems: [(Track, String)] = []
                        for track in tracksNeedingAnalysis {
                            if let trackItem = tracksResponse.data.first(where: { $0.id == track.id }) {
                                var previewUrl = trackItem.attributes.previews?.first?.url
                                if previewUrl == nil {
                                    previewUrl = trackItem.relationships?.catalog?.data?.first?.attributes.previews?.first?.url
                                }
                                if let finalPreviewUrl = previewUrl {
                                    print("✨ Found preview for '\(track.title)': \(finalPreviewUrl)")
                                    analysisItems.append((track, finalPreviewUrl))
                                } else {
                                    print("⚠️ No preview URL for '\(track.title)' (checked library and catalog)")
                                }
                            }
                        }
                        
                        print("📊 Analysis triggered for \(analysisItems.count)/\(tracksNeedingAnalysis.count) tracks (max 4 concurrent)")
                        
                        // Launch throttled analysis tasks using semaphore
                        let semaphore = self.bpmAnalysisSemaphore
                        for (track, previewUrl) in analysisItems {
                            Task {
                                await semaphore.wait()
                                await self.analyzeTrackBPM(track: track, previewUrl: previewUrl)
                                await semaphore.signal()
                            }
                        }
                    }
                } else {
                    print("ℹ️ BPM analysis skipped (using cached values only)")
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
    
    /// Analyze BPM for a track using backend, with retry logic for transient failures.
    /// Retries up to 3 times with exponential backoff on 500 errors.
    func analyzeTrackBPM(track: Track, previewUrl: String) async {
        let maxRetries = 3
        
        await MainActor.run {
            self.analyzingTrackCount += 1
        }
        
        defer {
            Task { @MainActor in
                self.analyzingTrackCount -= 1
            }
        }
        
        for attempt in 1...maxRetries {
            let success = await performBPMAnalysis(track: track, previewUrl: previewUrl, attempt: attempt)
            if success { return }
            
            if attempt < maxRetries {
                let delay = Double(attempt) * 2.0  // 2s, 4s backoff
                print("🔄 Retrying BPM analysis for '\(track.title)' in \(delay)s (attempt \(attempt + 1)/\(maxRetries))...")
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            } else {
                print("❌ BPM analysis permanently failed for '\(track.title)' after \(maxRetries) attempts")
            }
        }
    }
    
    /// Performs a single BPM analysis request. Returns true on success.
    private func performBPMAnalysis(track: Track, previewUrl: String, attempt: Int) async -> Bool {
        let host = "https://pulsetempo-production.up.railway.app"
        guard let url = URL(string: "\(host)/api/tracks/analyze") else { return false }
        
        if attempt == 1 {
            print("🔍 Analyzing BPM for track \(track.id)...")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        
        let body: [String: String] = [
            "apple_music_id": track.id,
            "preview_url": previewUrl
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 500 || httpResponse.statusCode == 503 || httpResponse.statusCode == 429 {
                    let responseBody = String(data: data, encoding: .utf8) ?? "Unknown"
                    print("❌ BPM API returned status \(httpResponse.statusCode) for '\(track.title)': \(responseBody)")
                    return false  // Retryable error
                }
                if httpResponse.statusCode != 200 {
                    let responseBody = String(data: data, encoding: .utf8) ?? "Unknown"
                    print("❌ BPM API returned status \(httpResponse.statusCode) for '\(track.title)': \(responseBody)")
                    return true  // Non-retryable error, don't keep trying
                }
            }
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let bpm = json["bpm"] as? Double {
                let bpmInt = Int(bpm)
                print("✅ BPM found for \(track.id): \(bpm)")
                
                let updatedTrack = Track(
                    id: track.id,
                    title: track.title,
                    artist: track.artist,
                    durationSeconds: track.durationSeconds,
                    bpm: bpmInt,
                    artworkURL: track.artworkURL,
                    isSkipped: track.isSkipped
                )
                
                await MainActor.run {
                    self.bpmCache[track.id] = bpmInt
                    let titleArtistKey = "\(track.title.lowercased())|\(track.artist.lowercased())"
                    self.bpmCache[titleArtistKey] = bpmInt
                    
                    if let index = self.trackQueue.firstIndex(where: { 
                        $0.id == updatedTrack.id || 
                        ($0.title.lowercased() == updatedTrack.title.lowercased() && 
                         $0.artist.lowercased() == updatedTrack.artist.lowercased()) 
                    }) {
                        self.trackQueue[index] = updatedTrack
                        print("📋 Updated trackQueue with BPM: '\(updatedTrack.title)' = \(bpmInt)")
                    }
                    
                    self.trackUpdatedSubject.send(updatedTrack)
                }
                return true
            }
            return true  // Got 200 but no BPM in response - don't retry
        } catch {
            print("❌ BPM Analysis network error for '\(track.title)': \(error.localizedDescription)")
            return false  // Network error is retryable
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
    func searchForTrack(_ track: Track) async throws -> Song {
        // Create a search request for the track
        // We search by title and artist for best match
        let searchTerm = "\(track.title) \(track.artist)"
        
        var request = MusicCatalogSearchRequest(term: searchTerm, types: [Song.self])
        request.limit = 5 // Get top 5 results
        
        let response = try await request.response()
        
        // Try to find the best match
        // Ideally we'd use the track ID if we have it from Apple Music
        guard let song = response.songs.first else {
            print("❌ Failed to find '\(track.title)' by \(track.artist) in Apple Music catalog")
            throw MusicKitError.itemNotFound
        }
        
        print("✅ Found catalog match: '\(track.title)' (ID: \(song.id.rawValue))")
        return song
    }
    
    // MARK: - Catalog Search (User-Facing)
    
    /// Search the Apple Music catalog for songs matching a query
    ///
    /// Used by the music search UI to let users find songs to add to playlists.
    /// Returns both Track models and a mapping of track IDs to preview URLs
    /// (needed for BPM analysis after adding to a playlist).
    ///
    /// - Parameter query: The search term (song title, artist, etc.)
    /// - Returns: Tuple of (tracks, previewURLs dictionary)
    func searchCatalog(query: String) async throws -> (tracks: [Track], previewURLs: [String: String]) {
        guard musicKitManager.isAuthorized else {
            throw MusicKitError.authorizationDenied
        }
        
        var request = MusicCatalogSearchRequest(term: query, types: [Song.self])
        request.limit = 25
        
        let response = try await request.response()
        
        var previewURLs: [String: String] = [:]
        let tracks = response.songs.map { song -> Track in
            let artworkURL = song.artwork?.url(width: 120, height: 120)
            
            // Extract preview URL for BPM analysis
            if let previewURL = song.previewAssets?.first?.url {
                previewURLs[song.id.rawValue] = previewURL.absoluteString
            }
            
            return Track(
                id: song.id.rawValue,
                title: song.title,
                artist: song.artistName,
                durationSeconds: Int((song.duration ?? 0)),
                bpm: nil,
                artworkURL: artworkURL
            )
        }
        
        return (tracks, previewURLs)
    }
    
    // MARK: - Add Track to Playlist
    
    /// Add a catalog song to a user's library playlist
    ///
    /// Uses MusicDataRequest with a POST body. MusicDataRequest handles auth
    /// tokens automatically. The body must be a Codable struct with a `data`
    /// array wrapper — raw JSONSerialization doesn't work here.
    ///
    /// - Parameters:
    ///   - trackId: The catalog song ID to add
    ///   - playlistId: The library playlist ID to add the song to
    func addTrackToPlaylist(trackId: String, playlistId: String) async throws {
        guard musicKitManager.isAuthorized else {
            print("❌ [AddTrack] Not authorized")
            throw MusicKitError.authorizationDenied
        }
        
        let urlString = "https://api.music.apple.com/v1/me/library/playlists/\(playlistId)/tracks"
        let url = URL(string: urlString)!
        
        // Build POST request — MusicDataRequest handles auth tokens automatically
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Encode body using Codable (required by MusicDataRequest — raw JSON doesn't work)
        let requestBody = AddTracksRequestBody(data: [
            AddTracksRequestItem(id: trackId, type: "songs")
        ])
        let encodedBody = try JSONEncoder().encode(requestBody)
        urlRequest.httpBody = encodedBody
        
        // Debug: log full request details
        let bodyString = String(data: encodedBody, encoding: .utf8) ?? "nil"
        print("")
        print("═══════════════════════════════════════════")
        print("📤 [AddTrack] POST \(urlString)")
        print("📤 [AddTrack] trackId: \(trackId)")
        print("📤 [AddTrack] playlistId: \(playlistId)")
        print("📤 [AddTrack] body: \(bodyString)")
        print("📤 [AddTrack] httpMethod: \(urlRequest.httpMethod ?? "nil")")
        print("📤 [AddTrack] Content-Type: \(urlRequest.value(forHTTPHeaderField: "Content-Type") ?? "nil")")
        print("═══════════════════════════════════════════")
        
        do {
            let request = MusicDataRequest(urlRequest: urlRequest)
            let response = try await request.response()
            
            // Debug: log response details
            let httpResponse = response.urlResponse as? HTTPURLResponse
            let statusCode = httpResponse?.statusCode ?? -1
            let responseDataSize = response.data.count
            let responseBody = String(data: response.data, encoding: .utf8) ?? "<\(responseDataSize) bytes>"
            
            print("")
            print("═══════════════════════════════════════════")
            print("✅ [AddTrack] Response received")
            print("✅ [AddTrack] HTTP status: \(statusCode)")
            print("✅ [AddTrack] Response size: \(responseDataSize) bytes")
            if responseDataSize > 0 && responseDataSize < 1000 {
                print("✅ [AddTrack] Response body: \(responseBody)")
            }
            print("✅ [AddTrack] Successfully added track \(trackId) to playlist \(playlistId)")
            print("═══════════════════════════════════════════")
            print("")
        } catch {
            print("")
            print("═══════════════════════════════════════════")
            print("❌ [AddTrack] REQUEST FAILED")
            print("❌ [AddTrack] Error type: \(type(of: error))")
            print("❌ [AddTrack] Error: \(error)")
            print("❌ [AddTrack] Localized: \(error.localizedDescription)")
            print("═══════════════════════════════════════════")
            print("")
            throw error
        }
    }
    
    // MARK: - Playback Observers
    
    /// Set up observers for playback state changes
    ///
    /// This monitors the ApplicationMusicPlayer for state changes and
    /// updates our published properties accordingly.
    private func setupPlaybackObservers() {
        // Observe playback state changes
        player.state.objectWillChange
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.updatePlaybackState()
                }
            }
            .store(in: &cancellables)
        
        // Observe queue changes (debounce and deduplicate to prevent duplicate processing)
        player.queue.objectWillChange
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .compactMap { [weak self] _ -> String? in
                // Extract SONG ID (not Entry ID) for deduplication
                // Entry IDs change when MusicKit creates new queue entries for the same song
                guard let entry = self?.player.queue.currentEntry,
                      let item = entry.item else {
                    return nil
                }
                if case .song(let song) = item {
                    return song.id.rawValue
                }
                return nil
            }
            .removeDuplicates()
            .sink { [weak self] _ in
                // Already on main thread via scheduler, call directly without Task wrapper
                // to avoid race conditions from separate async contexts
                self?.updateCurrentTrack()
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
    /// NOTE: Not @MainActor - called synchronously from main queue via Combine sink
    private func updateCurrentTrack() {
        if let currentEntry = player.queue.currentEntry, let item = currentEntry.item {
            switch item {
            case .song(let song):
                let songIdString = song.id.rawValue
                
                // Early exit if we've already processed this exact song (prevents duplicate processing)
                guard lastLoggedSongId != songIdString else {
                    return
                }
                
                // Mark this song as processed immediately to prevent duplicate calls
                lastLoggedSongId = songIdString
                
                // Update the cached catalog song for future queue operations
                // This ensures replaceNext() works correctly after skips or natural track progression
                currentCatalogSong = song
                
                // Reset playback timing for queue ready delay
                playbackStartTime = Date()
                
                // Get artwork from current song
                let artworkURL = song.artwork?.url(width: 300, height: 300)
                
                // Try to find matching track in our queue
                // First try by ID, then fallback to title + artist match
                // (Library IDs like "i.ABC" differ from catalog IDs like "1234567890")
                let matchingTrack = trackQueue.first(where: { $0.id == songIdString })
                    ?? trackQueue.first(where: { 
                        $0.title.lowercased() == song.title.lowercased() && 
                        $0.artist.lowercased() == song.artistName.lowercased() 
                    })
                
                // Debug: Log match status
                if let matchingTrack = matchingTrack {
                    print("🎯 Track matched: '\(matchingTrack.title)' - BPM: \(matchingTrack.bpm?.description ?? "nil")")
                } else {
                    print("⚠️ No match found for '\(song.title)' by '\(song.artistName)' (ID: \(songIdString))")
                    print("   Queue has \(trackQueue.count) tracks. Sample titles: \(trackQueue.prefix(3).map { $0.title })")
                }
                
                if let matchingTrack = matchingTrack {
                    // Use BPM from queue, or preserve existing currentTrack BPM if already set
                    let finalBPM = matchingTrack.bpm ?? currentTrack?.bpm
                    
                    // Create updated track with artwork from the song
                    currentTrack = Track(
                        id: matchingTrack.id,
                        title: matchingTrack.title,
                        artist: matchingTrack.artist,
                        durationSeconds: matchingTrack.durationSeconds,
                        bpm: finalBPM,
                        artworkURL: artworkURL,
                        isSkipped: matchingTrack.isSkipped
                    )
                } else {
                    // Preserve existing BPM if this is the same track
                    let existingBPM = (currentTrack?.title.lowercased() == song.title.lowercased()) ? currentTrack?.bpm : nil
                    
                    // Create a new track from the song
                    currentTrack = Track(
                        id: songIdString,
                        title: song.title,
                        artist: song.artistName,
                        durationSeconds: Int(song.duration ?? 0),
                        bpm: existingBPM,
                        artworkURL: artworkURL
                    )
                }
                
                // Log the new song
                let duration = song.duration.map { Int($0) } ?? 0
                let minutes = duration / 60
                let seconds = duration % 60
                print("▶️ NOW PLAYING: '\(song.title)' by \(song.artistName) [\(minutes):\(String(format: "%02d", seconds))]")
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
    
    // Custom Equatable implementation since Artwork is not Equatable
    static func == (lhs: MusicPlaylist, rhs: MusicPlaylist) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.trackCount == rhs.trackCount
        // Note: We don't compare artwork since it's not Equatable
    }
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
    let relationships: LibraryTrackRelationships?
}

private struct LibraryTrackAttributes: Codable {
    let name: String
    let artistName: String
    let durationInMillis: Int
    let previews: [PreviewAsset]?
    let artwork: ArtworkAttributes?
}

private struct ArtworkAttributes: Codable {
    let url: String?
    let width: Int?
    let height: Int?
    
    /// Generate artwork URL with specified dimensions
    func url(width: Int, height: Int) -> URL? {
        guard let urlTemplate = url else { return nil }
        let urlString = urlTemplate
            .replacingOccurrences(of: "{w}", with: "\(width)")
            .replacingOccurrences(of: "{h}", with: "\(height)")
        return URL(string: urlString)
    }
}

private struct PreviewAsset: Codable {
    let url: String
}

private struct LibraryTrackRelationships: Codable {
    let catalog: CatalogRelationship?
}

private struct CatalogRelationship: Codable {
    let data: [CatalogTrackItem]?
}

private struct CatalogTrackItem: Codable {
    let id: String
    let attributes: CatalogTrackAttributes
}

private struct CatalogTrackAttributes: Codable {
    let previews: [PreviewAsset]?
}

// MARK: - Add Tracks Request Models

/// Codable body for POST /v1/me/library/playlists/{id}/tracks
/// MusicDataRequest requires Codable encoding — raw JSONSerialization fails with "Unable to parse request body"
private struct AddTracksRequestBody: Codable {
    let data: [AddTracksRequestItem]
}

private struct AddTracksRequestItem: Codable {
    let id: String
    let type: String
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

// MARK: - Async Semaphore

/// Simple actor-based semaphore to limit concurrency of async tasks.
/// Used to throttle BPM analysis requests so we don't overwhelm the backend.
actor AsyncSemaphore {
    private let limit: Int
    private var count: Int = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []
    
    init(limit: Int) {
        self.limit = limit
    }
    
    func wait() async {
        if count < limit {
            count += 1
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }
    
    func signal() {
        if let next = waiters.first {
            waiters.removeFirst()
            next.resume()
        } else {
            count -= 1
        }
    }
}

