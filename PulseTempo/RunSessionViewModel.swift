//
//  RunSessionViewModel.swift
//  PulseTempo
//
//  Created by Zavier Rodrigues on 11/4/25.
//

// IMPORTS
import Foundation  // Basic types and utilities
import SwiftUI     // UI framework (needed for @Published)
import Combine     // Reactive programming framework (like RxPy or asyncio in Python)
import MusicKit    // Apple Music integration

// VIEW MODEL CLASS
// This is the "business logic" layer - separates data/logic from UI
// Think of it like a FastAPI service class or a Python controller
//
// Python equivalent concept:
// class RunSessionViewModel:
//     def __init__(self):
//         self.is_playing = True
//         self.current_track = None
//         ...
//
// KEY CONCEPTS:
// - "final" = cannot be subclassed (like @final in Python 3.8+)
// - "ObservableObject" = protocol that allows SwiftUI to watch for changes
//   (like a reactive state manager - when properties change, UI auto-updates)
final class RunSessionViewModel: ObservableObject {
    
    // ═══════════════════════════════════════════════════════════
    // PUBLISHED PROPERTIES (Observable State)
    // ═══════════════════════════════════════════════════════════
    // MARK: - Published Properties
    // @Published is a property wrapper that automatically notifies the UI when the value changes
    // Similar to React's useState or Vue's reactive properties
    // When these change, any UI using them will automatically re-render
    //
    // Python analogy: Think of @Published like a property with a built-in observer pattern
    // that triggers callbacks whenever the value is set
    
    // PLAYBACK STATE
    @Published var isPlaying: Bool = false       // Is music currently playing?
    @Published var currentTrack: Track?          // Currently playing track (? = Optional/None)
    @Published var currentHeartRate: Int = 0     // Current heart rate in BPM
    
    // RUN SESSION STATE
    @Published var sessionState: RunSessionState = .notStarted  // Current run state
    @Published var elapsedTime: TimeInterval = 0                // Time since run started (seconds)
    
    // RUN METRICS
    @Published var averageHeartRate: Int = 0     // Average HR during run
    @Published var maxHeartRate: Int = 0         // Maximum HR during run
    @Published var tracksPlayed: [Track] = []    // History of tracks played
    
    // ERROR HANDLING
    @Published var errorMessage: String?         // User-friendly error message
    
    // ═══════════════════════════════════════════════════════════
    // REGULAR PROPERTIES
    // ═══════════════════════════════════════════════════════════
    // MARK: - Properties
    
    let runMode: RunMode = .steadyTempo          // The workout mode (constant for now)
    
    // ═══════════════════════════════════════════════════════════
    // PRIVATE PROPERTIES
    // ═══════════════════════════════════════════════════════════
    // MARK: - Private Properties
    
    // SERVICE INSTANCES
    // These are the core services that power the app
    private let heartRateService = HeartRateService()  // Monitors heart rate
    private let musicService = MusicService()          // Controls music playback
    
    // TRACK MANAGEMENT
    private var tracks: [Track] = []             // All available tracks
    private var currentIndex: Int = 0            // Index of current track in the array
    private var playedTrackIds: Set<String> = [] // Track IDs already played (avoid repetition)
    
    // RUN METRICS TRACKING
    private var runStartTime: Date?              // When the run started
    private var heartRateSamples: [Int] = []     // All HR samples for averaging
    private var runTimer: Timer?                 // Timer for updating elapsed time
    
    // COMBINE SUBSCRIPTIONS
    // Store subscriptions so they don't get deallocated
    // Like keeping references to asyncio tasks or RxPy subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    // ═══════════════════════════════════════════════════════════
    // INITIALIZATION
    // ═══════════════════════════════════════════════════════════
    // MARK: - Initialization
    
    // INITIALIZER (Constructor)
    // Like Python's __init__ method
    // Called when creating a new instance: let vm = RunSessionViewModel(tracks: myTracks)
    //
    // Python equivalent:
    // def __init__(self, tracks):
    //     self.heart_rate_service = HeartRateService()
    //     self.music_service = MusicService()
    //     self.tracks = tracks
    //     self._setup_observers()
    init(tracks: [Track] = []) {
        self.tracks = tracks.isEmpty ? createFakeTracks() : tracks
        setupObservers()                         // Connect to service updates
        
        print("🎵 RunSessionViewModel initialized with \(self.tracks.count) tracks")
    }
    
    // ═══════════════════════════════════════════════════════════
    // SETUP METHODS
    // ═══════════════════════════════════════════════════════════
    // MARK: - Setup
    
    /// Sets up reactive subscriptions to service updates
    /// This is the "glue" that connects services to the view model
    ///
    /// Python equivalent:
    /// def _setup_observers(self):
    ///     # Subscribe to heart rate updates
    ///     self.heart_rate_service.current_heart_rate.subscribe(
    ///         lambda hr: self._on_heart_rate_changed(hr)
    ///     )
    ///     # Subscribe to music playback state
    ///     self.music_service.playback_state.subscribe(
    ///         lambda state: self._on_playback_state_changed(state)
    ///     )
    private func setupObservers() {
        // OBSERVE HEART RATE CHANGES
        // $currentHeartRate is a Publisher that emits whenever the property changes
        // .sink() subscribes to those changes (like .subscribe() in RxPy)
        // [weak self] prevents memory leaks (weak reference to self)
        heartRateService.$currentHeartRate
            .sink { [weak self] heartRate in
                self?.onHeartRateChanged(heartRate)
            }
            .store(in: &cancellables)  // Store subscription so it stays alive
        
        // OBSERVE MUSIC PLAYBACK STATE
        musicService.$playbackState
            .sink { [weak self] state in
                self?.isPlaying = (state == .playing)
            }
            .store(in: &cancellables)
        
        // OBSERVE CURRENT TRACK FROM MUSIC SERVICE
        musicService.$currentTrack
            .sink { [weak self] track in
                if let track = track {
                    self?.currentTrack = track
                    self?.tracksPlayed.append(track)
                }
            }
            .store(in: &cancellables)
        
        // OBSERVE ERRORS FROM SERVICES
        heartRateService.$error
            .compactMap { $0 }  // Filter out nil values
            .sink { [weak self] error in
                self?.errorMessage = "Heart Rate Error: \(error.localizedDescription)"
            }
            .store(in: &cancellables)
        
        musicService.$error
            .compactMap { $0 }
            .sink { [weak self] error in
                self?.errorMessage = "Music Error: \(error.localizedDescription)"
            }
            .store(in: &cancellables)
    }
    
    // PRIVATE METHOD: createFakeTracks
    // Creates dummy data for testing (like fixture data in Python tests)
    // "private func" = private method (like Python methods starting with _)
    //
    // Python equivalent:
    // def _create_fake_tracks(self) -> List[Track]:
    //     return [
    //         Track(id="1", title="Eye of the Tiger", ...),
    //         Track(id="2", title="Stronger", ...),
    //     ]
    private func createFakeTracks() -> [Track] {
        // Create an array of Track objects
        // In Swift, you create objects by calling StructName(property: value, ...)
        // Similar to Python: Track(id="1", title="Eye of the Tiger", ...)
        return [
            Track(
                id: "1",
                title: "Eye of the Tiger",
                artist: "Survivor",
                durationSeconds: 245,
                bpm: 109
            ),
            Track(
                id: "2",
                title: "Stronger",
                artist: "Kanye West",
                durationSeconds: 312,
                bpm: 104
            ),
            Track(
                id: "3",
                title: "Lose Yourself",
                artist: "Eminem",
                durationSeconds: 326,
                bpm: 171
            ),
            Track(
                id: "4",
                title: "Can't Stop",
                artist: "Red Hot Chili Peppers",
                durationSeconds: 269,
                bpm: 126
            ),
            Track(
                id: "5",
                title: "Till I Collapse",
                artist: "Eminem",
                durationSeconds: 297,
                bpm: 166
            ),
            Track(
                id: "6",
                title: "Thunder",
                artist: "Imagine Dragons",
                durationSeconds: 187,
                bpm: 85
            )
        ]
    }
    
    // ═══════════════════════════════════════════════════════════
    // PUBLIC METHODS - Run Control
    // ═══════════════════════════════════════════════════════════
    // MARK: - Run Control
    
    /// Start the run session
    /// Begins heart rate monitoring and music playback
    ///
    /// Python equivalent:
    /// def start_run(self):
    ///     self.session_state = RunSessionState.ACTIVE
    ///     self.run_start_time = datetime.now()
    ///     
    ///     # Start heart rate monitoring
    ///     self.heart_rate_service.start_monitoring(callback=self._on_monitoring_started)
    ///     
    ///     # Start music playback
    ///     if self.tracks:
    ///         self.music_service.play_queue(self.tracks, callback=self._on_playback_started)
    ///     
    ///     # Start timer for elapsed time
    ///     self.run_timer = Timer.schedule_repeating(interval=1.0, callback=self._update_elapsed_time)
    func startRun() {
        // Update state
        sessionState = .active
        runStartTime = Date()
        heartRateSamples.removeAll()
        playedTrackIds.removeAll()
        tracksPlayed.removeAll()
        
        // Start heart rate monitoring
        // Check if we should use demo mode (no Apple Watch available)
        let useDemoMode = !HealthKitManager.shared.isHealthKitAvailable
        
        heartRateService.startMonitoring(useDemoMode: useDemoMode) { [weak self] result in
            switch result {
            case .success:
                print("✅ Heart rate monitoring started")
            case .failure(let error):
                self?.errorMessage = "Failed to start heart rate monitoring: \(error.localizedDescription)"
            }
        }
        
        // Start music playback with initial track selection
        if !tracks.isEmpty {
            // Select first track based on initial heart rate (or default 120 BPM)
            let initialTrack = selectTrackForHeartRate(120)
            
            // Set current track immediately so UI shows it
            currentTrack = initialTrack
            print("🎵 Selected track: \(initialTrack.title) by \(initialTrack.artist)")
            
            musicService.play(track: initialTrack) { [weak self] result in
                switch result {
                case .success:
                    print("✅ Music playback started")
                case .failure(let error):
                    print("⚠️ Music playback failed: \(error.localizedDescription)")
                    self?.errorMessage = "Failed to start music: \(error.localizedDescription)"
                }
            }
        }
        
        // Start timer for elapsed time
        runTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateElapsedTime()
        }
    }
    
    /// Pause the run session
    /// Pauses music but continues heart rate monitoring
    func pauseRun() {
        sessionState = .paused
        isPlaying = false  // Update UI immediately
        musicService.pause()
        runTimer?.invalidate()
    }
    
    /// Resume the run session
    /// Resumes music playback
    func resumeRun() {
        sessionState = .active
        isPlaying = true  // Update UI immediately
        musicService.resume()
        
        // Restart elapsed time timer
        runTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateElapsedTime()
        }
    }
    
    /// Stop the run session
    /// Stops both heart rate monitoring and music playback
    func stopRun() {
        sessionState = .completed
        
        // Stop services
        heartRateService.stopMonitoring()
        musicService.stop()
        
        // Stop timer
        runTimer?.invalidate()
        runTimer = nil
        
        // Calculate final metrics
        calculateFinalMetrics()
    }
    
    /// Toggle play/pause state
    /// Pauses or resumes based on current state
    ///
    /// Python equivalent:
    /// def toggle_play_pause(self):
    ///     if self.session_state == RunSessionState.ACTIVE:
    ///         self.pause_run()
    ///     elif self.session_state == RunSessionState.PAUSED:
    ///         self.resume_run()
    func togglePlayPause() {
        switch sessionState {
        case .active:
            pauseRun()
        case .paused:
            resumeRun()
        default:
            break
        }
    }
    
    /// Skip to next track
    /// Manually skip to the next track (uses current or provided heart rate for selection)
    /// - Parameter approximateHeartRate: Optional heart rate to use for track selection (defaults to current heart rate)
    func skipToNextTrack(approximateHeartRate: Int? = nil) {
        guard !tracks.isEmpty else { return }
        
        // Use provided heart rate or fall back to current heart rate
        let targetHeartRate = approximateHeartRate ?? currentHeartRate
        
        // Select next track based on target heart rate
        let nextTrack = selectTrackForHeartRate(targetHeartRate)
        
        // Play the selected track
        musicService.play(track: nextTrack) { result in
            if case .failure(let error) = result {
                print("Failed to skip track: \(error)")
            }
        }
    }
    
    /// Skip to previous track
    /// Goes back to the previously played track in the session
    func skipToPreviousTrack() {
        // Need at least 2 tracks in history (current + previous)
        guard tracksPlayed.count >= 2 else {
            print("⚠️ No previous track available")
            return
        }
        
        // Remove current track from history
        tracksPlayed.removeLast()
        
        // Get the previous track
        let previousTrack = tracksPlayed.last!
        
        // Remove it from history so it can be re-added when played
        tracksPlayed.removeLast()
        
        // Remove from played IDs so it can be selected again
        playedTrackIds.remove(previousTrack.id)
        
        // Play the previous track
        currentTrack = previousTrack
        print("⏮️ Going back to: \(previousTrack.title) by \(previousTrack.artist)")
        
        musicService.play(track: previousTrack) { result in
            if case .failure(let error) = result {
                print("Failed to play previous track: \(error)")
            }
        }
    }
    
    // ═══════════════════════════════════════════════════════════
    // PRIVATE METHODS - Heart Rate & BPM Matching
    // ═══════════════════════════════════════════════════════════
    // MARK: - Heart Rate Handling
    
    /// Called when heart rate changes - implements smart track selection
    private func onHeartRateChanged(_ heartRate: Int) {
        currentHeartRate = heartRate
        
        guard sessionState == .active else { return }
        
        // Track metrics
        heartRateSamples.append(heartRate)
        if heartRate > maxHeartRate {
            maxHeartRate = heartRate
        }
        
        // Calculate average
        if !heartRateSamples.isEmpty {
            averageHeartRate = heartRateSamples.reduce(0, +) / heartRateSamples.count
        }
        
        // Check if track change needed
        checkTrackChangeNeeded(heartRate)
    }
    
    /// Check if current track BPM matches heart rate
    private func checkTrackChangeNeeded(_ heartRate: Int) {
        guard let track = currentTrack, let trackBPM = track.bpm else { return }
        
        let bpmDifference = abs(trackBPM - heartRate)
        let tolerance = getBPMTolerance()
        
        if bpmDifference > tolerance {
            let betterTrack = selectTrackForHeartRate(heartRate)
            musicService.playNext(track: betterTrack)
        }
    }
    
    /// Get BPM tolerance based on run mode
    private func getBPMTolerance() -> Int {
        switch runMode {
        case .steadyTempo: return 10
        case .progressiveBuild: return 15
        case .recovery: return 8
        }
    }
    
    /// Select best track for given heart rate with smart BPM matching
    private func selectTrackForHeartRate(_ heartRate: Int) -> Track {
        var availableTracks = tracks.filter { !playedTrackIds.contains($0.id) }
        
        if availableTracks.isEmpty {
            playedTrackIds.removeAll()
            availableTracks = tracks
        }
        
        let scoredTracks = availableTracks.map { track -> (score: Double, track: Track) in
            let score = scoreTrack(track, forHeartRate: heartRate)
            return (score, track)
        }
        
        guard let bestMatch = scoredTracks.max(by: { $0.score < $1.score }) else {
            return tracks[0]
        }
        
        playedTrackIds.insert(bestMatch.track.id)
        return bestMatch.track
    }
    
    /// Score a track for heart rate matching (higher = better)
    private func scoreTrack(_ track: Track, forHeartRate heartRate: Int) -> Double {
        guard let trackBPM = track.bpm else { return 0.0 }
        
        // BPM match score (60% weight)
        let bpmDifference = abs(trackBPM - heartRate)
        let bpmScore = max(0, 1 - Double(bpmDifference) / 50.0)
        
        // Variety score (20% weight)
        let varietyScore = 1.0
        
        // Energy score (20% weight)
        let energyScore = calculateEnergyScore(trackBPM: trackBPM, heartRate: heartRate)
        
        return (bpmScore * 0.6) + (varietyScore * 0.2) + (energyScore * 0.2)
    }
    
    /// Calculate energy score based on heart rate zone
    private func calculateEnergyScore(trackBPM: Int, heartRate: Int) -> Double {
        let hrPercentage = Double(heartRate) / 200.0
        
        let idealTrackBPM: Double
        if hrPercentage < 0.7 {
            idealTrackBPM = 100
        } else if hrPercentage < 0.8 {
            idealTrackBPM = 130
        } else if hrPercentage < 0.9 {
            idealTrackBPM = 150
        } else {
            idealTrackBPM = 170
        }
        
        let difference = abs(Double(trackBPM) - idealTrackBPM)
        return max(0, 1 - difference / 50.0)
    }
    
    // ═══════════════════════════════════════════════════════════
    // PRIVATE METHODS - Metrics
    // ═══════════════════════════════════════════════════════════
    // MARK: - Metrics
    
    /// Update elapsed time (called every second by timer)
    private func updateElapsedTime() {
        guard let startTime = runStartTime else { return }
        elapsedTime = Date().timeIntervalSince(startTime)
    }
    
    /// Calculate final metrics when run completes
    private func calculateFinalMetrics() {
        // Final average already calculated incrementally
        // Could add more complex metrics here
        print("📊 Run completed - Avg HR: \(averageHeartRate), Max HR: \(maxHeartRate), Duration: \(Int(elapsedTime))s")
    }
}
