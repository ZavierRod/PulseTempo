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
@MainActor
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
    private let heartRateService: HeartRateServiceProtocol  // Monitors heart rate
    private let musicService: MusicServiceProtocol          // Controls music playback
    
    // TRACK MANAGEMENT
    private var tracks: [Track] = []             // All available tracks
    private var currentIndex: Int = 0            // Index of current track in the array
    private var playedTrackIds: Set<String> = [] // Track IDs already played (avoid repetition)
    private var tracksPlayedInternal: [Track] = [] // Internal copy for navigationQueue access
    private let navigationQueue = DispatchQueue(label: "RunSessionViewModel.navigationQueue")
    private enum NavigationDirection {
        case next
        case previous
    }
    
    // NEXT TRACK QUEUE MANAGEMENT
    // Per ROADMAP: intelligently select ONE next track that updates as HR changes
    private var queuedNextTrack: Track?          // The track queued to play next

    private var lastSkipTimestamps: [NavigationDirection: Date] = [:]
    private let skipDebounceInterval: TimeInterval = 0.3

    var playedTrackIdsSnapshot: Set<String> {
        navigationQueue.sync { playedTrackIds }
    }
    
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
    init(
        tracks: [Track] = [],
        heartRateService: HeartRateServiceProtocol = HeartRateService(),
        musicService: MusicServiceProtocol = MusicService()
    ) {
        self.heartRateService = heartRateService
        self.musicService = musicService
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
        heartRateService.currentHeartRatePublisher
            .sink { [weak self] heartRate in
                self?.onHeartRateChanged(heartRate)
            }
            .store(in: &cancellables)  // Store subscription so it stays alive
        
        // OBSERVE MUSIC PLAYBACK STATE
        musicService.playbackStatePublisher
            .sink { [weak self] state in
                self?.isPlaying = (state == .playing)
            }
            .store(in: &cancellables)

        // OBSERVE CURRENT TRACK FROM MUSIC SERVICE
        musicService.currentTrackPublisher
            .sink { [weak self] track in
                if let track = track {
                    self?.recordTrackFromService(track)
                }
            }
            .store(in: &cancellables)
        
        // OBSERVE ERRORS FROM SERVICES
        heartRateService.errorPublisher
            .compactMap { $0 }  // Filter out nil values
            .sink { [weak self] error in
                self?.errorMessage = "Heart Rate Error: \(error.localizedDescription)"
            }
            .store(in: &cancellables)
        
        musicService.errorPublisher
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
    /// Per ROADMAP: User starts workout, app plays either random track or user-chosen track
    /// BPM matching isn't critical at start since user isn't warmed up yet
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
        tracksPlayedInternal.removeAll()
        queuedNextTrack = nil  // Clear queued track
        
        // Start heart rate monitoring
        // Get the selected wearable device from device manager
        let selectedDevice = WearableDeviceManager.loadDevicePreference()
        let useDemoMode = selectedDevice == .demoMode || !HealthKitManager.shared.isHealthKitAvailable
        
        heartRateService.startMonitoring(device: selectedDevice, useDemoMode: useDemoMode) { [weak self] result in
            switch result {
            case .success:
                print("✅ Heart rate monitoring started with \(selectedDevice.rawValue)")
            case .failure(let error):
                self?.errorMessage = "Failed to start heart rate monitoring: \(error.localizedDescription)"
            }
        }
        
        // Start music playback with initial track selection
        if !tracks.isEmpty {
            // Select first track based on initial heart rate (or default 120 BPM)
            let initialTrack = selectTrackForHeartRate(120)
            
            // Set current track immediately so UI shows it
            queueTrackForPlayback(initialTrack, historyBaseline: [])
        }
        
        // Timer scheduled on main runloop because RunSessionViewModel is @MainActor
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
        
        // Timer scheduled on main runloop because RunSessionViewModel is @MainActor
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
    /// Per ROADMAP: User manually skips forward - this is one of two ways queued track plays
    /// (The other is when current song ends naturally)
    /// - Parameter approximateHeartRate: Optional heart rate to use for track selection (defaults to current heart rate)
    func skipToNextTrack(approximateHeartRate: Int? = nil) {
        navigationQueue.async { [weak self] in
            guard let self else { return }
            guard self.allowNavigationAction(.next) else { return }
            guard !self.tracks.isEmpty else { return }

            let targetHeartRate = approximateHeartRate ?? self.currentHeartRate
            let nextTrack = self.selectTrackForHeartRate(targetHeartRate)
            self.playTrack(nextTrack)
            
            // Clear queued track since we're manually navigating
            self.queuedNextTrack = nil
        }
    }
    
    /// Skip to previous track
    /// Per ROADMAP: User manually skips backward
    /// Goes back to the previously played track in the session
    func skipToPreviousTrack() {
        navigationQueue.async { [weak self] in
            guard let self else { return }
            guard self.allowNavigationAction(.previous) else { return }

            guard self.tracksPlayedInternal.count >= 2 else {
                print("⚠️ No previous track available")
                return
            }

            var updatedHistory = self.tracksPlayedInternal
            let current = updatedHistory.removeLast()
            let previousTrack = updatedHistory.removeLast()

            var updatedPlayedIds = self.playedTrackIds
            updatedPlayedIds.remove(current.id)
            updatedPlayedIds.remove(previousTrack.id)

            self.playTrack(previousTrack, historyBaseline: updatedHistory, playedIdsBaseline: updatedPlayedIds)
            
            // Clear queued track since we're manually navigating
            self.queuedNextTrack = nil
        }
    }
    
    // ═══════════════════════════════════════════════════════════
    // PRIVATE METHODS - Heart Rate & BPM Matching
    // ═══════════════════════════════════════════════════════════
    // MARK: - Heart Rate Handling
    
    /// Called when heart rate changes - implements smart track selection
    /// Per ROADMAP: Continuously monitors HR and intelligently selects NEXT track
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
        
        // Update queued next track based on HR changes
        // Per ROADMAP: Never interrupt current song, queue intelligently updates
        updateQueuedNextTrack(heartRate)
    }
    
    /// Update the queued next track based on current heart rate
    /// Per ROADMAP: App intelligently selects the NEXT track that matches current HR
    /// Key Principle: Never interrupt the currently playing song
    /// Next track plays when: (1) current song ends naturally, OR (2) user manually skips
    ///
    /// Example: HR at 160 → queue 160 BPM song. HR changes to 140 → REPLACE with 140 BPM song.
    private func updateQueuedNextTrack(_ heartRate: Int) {
        // Select the best track for current heart rate
        let bestMatchTrack = selectTrackForHeartRate(heartRate)
        
        // Only update queue if it's different from what's already queued
        // This prevents repeatedly queueing the same track
        guard queuedNextTrack?.id != bestMatchTrack.id else {
            return
        }
        
        // Update our internal queue state
        let hadPreviouslyQueuedTrack = queuedNextTrack != nil
        queuedNextTrack = bestMatchTrack
        
        // Replace the queued track (ensures queue size of 1)
        // If there was a previously queued track, this replaces it
        // If not, this queues the first track
        musicService.replaceNext(track: bestMatchTrack)
        
        let action = hadPreviouslyQueuedTrack ? "Replaced" : "Queued"
        print("🎵 \(action) next track: \(bestMatchTrack.title) (\(bestMatchTrack.bpm ?? 0) BPM) for HR: \(heartRate)")
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
        // let varietyScore = 1.0
        let varietyScore = playedTrackIds.contains(track.id) ? 0.5 : 1.0
        
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
    
    deinit {
        // Ensure timers and services are stopped on deallocation to avoid runloop callbacks
        runTimer?.invalidate()
        runTimer = nil
        // Defensive: stop services in case stopRun() wasn't called
        heartRateService.stopMonitoring()
        musicService.stop()
        cancellables.removeAll()
    }
}

// MARK: - Track State Management
private extension RunSessionViewModel {
    private func allowNavigationAction(_ direction: NavigationDirection) -> Bool {
        let now = Date()
        if let last = lastSkipTimestamps[direction], now.timeIntervalSince(last) < skipDebounceInterval {
            return false
        }
        lastSkipTimestamps[direction] = now
        return true
    }

    func recordTrackFromService(_ track: Track) {
        navigationQueue.async { [weak self] in
            guard let self else { return }
            var updatedHistory = self.tracksPlayedInternal
            if updatedHistory.last?.id != track.id {
                updatedHistory.append(track)
            }

            var updatedIds = self.playedTrackIds
            updatedIds.insert(track.id)

            self.dispatchStateUpdate(track: track, history: updatedHistory, playedIds: updatedIds)
        }
    }

    func queueTrackForPlayback(_ track: Track, historyBaseline: [Track]?) {
        navigationQueue.async { [weak self] in
            guard let self else { return }
            var updatedHistory = historyBaseline ?? self.tracksPlayedInternal
            updatedHistory.append(track)
            var updatedIds = self.playedTrackIds
            updatedIds.insert(track.id)

            self.dispatchStateUpdate(track: track, history: updatedHistory, playedIds: updatedIds)

            self.musicService.play(track: track) { [weak self] result in
                if case .failure(let error) = result {
                    print("Failed to start music: \(error)")
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func playTrack(_ track: Track, historyBaseline: [Track]? = nil, playedIdsBaseline: Set<String>? = nil) {
        var updatedHistory = historyBaseline ?? tracksPlayedInternal
        updatedHistory.append(track)
        var updatedIds = playedIdsBaseline ?? playedTrackIds
        updatedIds.insert(track.id)

        dispatchStateUpdate(track: track, history: updatedHistory, playedIds: updatedIds)

        musicService.play(track: track) { [weak self] result in
            if case .failure(let error) = result {
                print("Failed to play track: \(error)")
                self?.errorMessage = error.localizedDescription
            }
        }
    }

    func dispatchStateUpdate(track: Track, history: [Track], playedIds: Set<String>) {
        // Update internal state on navigation queue
        tracksPlayedInternal = history
        playedTrackIds = playedIds
        
        // Update published properties on main queue for UI
        DispatchQueue.main.async {
            self.tracksPlayed = history
            self.currentTrack = track
        }
    }
    
    // MARK: - Test Helpers
    
    /// Flush the navigation queue - for testing only
    internal func flushNavigationQueue(completion: @escaping () -> Void) {
        navigationQueue.async {
            DispatchQueue.main.async {
                completion()
            }
        }
    }
}

