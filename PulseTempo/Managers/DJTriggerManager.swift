import Foundation
import Combine

/// Manages automatic DJ trigger logic during a workout session.
/// Monitors song position, elapsed time, and heart rate zone changes
/// to intelligently fire the AI DJ at the right moments.
@MainActor
class DJTriggerManager: ObservableObject {
    
    // MARK: - Configuration
    
    /// Minimum seconds between DJ interruptions (cooldown)
    private let cooldownInterval: TimeInterval = 90
    
    /// How often (in workout minutes) the DJ gives a time-based check-in
    private let checkInIntervalMinutes: Int = 5
    
    /// How many seconds before a song ends to trigger a "song transition" announcement
    private let songEndThreshold: Int = 15
    
    /// Don't speak in the first N seconds of a song (let the listener enjoy the intro)
    private let songStartBuffer: Int = 30
    
    // MARK: - Internal State
    
    private var lastSpeakTime: Date = .distantPast
    private var lastCheckInMinute: Int = -1
    private var lastHRZone: HeartRateZone = .rest
    private var lastAnnouncedMilestone: Int = -1
    private var hasFiredSongTransition: Bool = false
    private var lastTrackId: String?
    
    private var cancellables = Set<AnyCancellable>()
    private var tickTimer: Timer?
    
    /// Reference to the active run session (set when workout starts)
    weak var runSessionVM: RunSessionViewModel?
    
    @Published var isEnabled: Bool = true
    
    // MARK: - Lifecycle
    
    /// Start monitoring the workout for DJ trigger opportunities
    func startMonitoring(vm: RunSessionViewModel) {
        self.runSessionVM = vm
        
        // Tick every 2 seconds to check trigger conditions
        tickTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.evaluateTriggers()
            }
        }
        
        print("🎙️ [DJTriggerManager] Started monitoring for DJ trigger events.")
    }
    
    /// Stop monitoring (when workout ends)
    func stopMonitoring() {
        tickTimer?.invalidate()
        tickTimer = nil
        cancellables.removeAll()
        print("🎙️ [DJTriggerManager] Stopped monitoring.")
    }
    
    // MARK: - Core Trigger Evaluation
    
    private func evaluateTriggers() {
        guard isEnabled, let vm = runSessionVM else { return }
        guard vm.sessionState == .active else { return }
        
        // Don't trigger if the DJ is currently speaking
        guard !DJVoiceManager.shared.isSpeaking else { return }
        
        // Enforce cooldown
        let timeSinceLastSpeak = Date().timeIntervalSince(lastSpeakTime)
        guard timeSinceLastSpeak >= cooldownInterval else { return }
        
        let currentTrack = vm.currentTrack
        let playbackTime = Int(vm.currentPlaybackTime)
        let songDuration = currentTrack?.durationSeconds ?? 0
        let timeRemaining = songDuration - playbackTime
        let elapsedMinutes = Int(vm.elapsedTime / 60)
        let currentZone = HeartRateZone.zone(for: vm.currentHeartRate)
        
        // --- Detect track change and reset song-transition flag ---
        if let trackId = currentTrack?.id, trackId != lastTrackId {
            lastTrackId = trackId
            hasFiredSongTransition = false
        }
        
        // --- TRIGGER 1: Song Transition (highest priority) ---
        // Fire ~15 seconds before the song ends to introduce the next track
        if songDuration > 0 && timeRemaining <= songEndThreshold && timeRemaining > 0 && !hasFiredSongTransition {
            hasFiredSongTransition = true
            fireDJ(reason: "song_transition")
            return
        }
        
        // --- Smart timing: don't speak in first 30s or last 10s of a song ---
        let inSafeWindow = playbackTime >= songStartBuffer && timeRemaining > 10
        guard inSafeWindow || songDuration == 0 else { return }
        
        // --- TRIGGER 2: HR Zone Change ---
        if currentZone != lastHRZone {
            let previousZone = lastHRZone
            lastHRZone = currentZone
            // Only fire for significant zone shifts (not rest→warmup at start)
            if vm.elapsedTime > 60 && previousZone != .rest {
                fireDJ(reason: "hr_zone_change")
                return
            }
        }
        
        // --- TRIGGER 3: Workout Milestones (every 10 minutes) ---
        let milestoneMinute = (elapsedMinutes / 10) * 10
        if milestoneMinute > 0 && milestoneMinute != lastAnnouncedMilestone && elapsedMinutes >= milestoneMinute {
            lastAnnouncedMilestone = milestoneMinute
            fireDJ(reason: "workout_milestone_\(milestoneMinute)min")
            return
        }
        
        // --- TRIGGER 4: Time-Based Check-in (every 5 minutes) ---
        if elapsedMinutes > 0 && elapsedMinutes % checkInIntervalMinutes == 0 && elapsedMinutes != lastCheckInMinute {
            lastCheckInMinute = elapsedMinutes
            fireDJ(reason: "time_checkin")
            return
        }
    }
    
    // MARK: - Fire the DJ
    
    private func fireDJ(reason: String) {
        guard let vm = runSessionVM else { return }
        
        lastSpeakTime = Date()
        
        let runnerName = AuthService.shared.currentUser?.username ?? "Runner"
        
        // Only include next-song data for song_transition triggers
        // to avoid announcing a queued track that might change by the time the song ends
        let isSongTransition = reason == "song_transition"
        
        let context = DJContext(
            runnerName: runnerName,
            currentHeartRate: vm.currentHeartRate,
            elapsedTime: vm.elapsedTime,
            currentSongTitle: vm.currentTrack?.title ?? "Unknown Track",
            currentSongArtist: vm.currentTrack?.artist ?? "Unknown Artist",
            currentSongElapsed: Int(vm.currentPlaybackTime),
            currentSongDuration: vm.currentTrack?.durationSeconds ?? 0,
            nextSongTitle: isSongTransition ? vm.queuedNextTrack?.title : nil,
            nextSongArtist: isSongTransition ? vm.queuedNextTrack?.artist : nil,
            triggerReason: reason
        )
        
        print("🎙️ [DJTriggerManager] 🔥 Firing DJ! Reason: \(reason)")
        
        Task {
            do {
                let script = try await OpenAIPromptService.shared.generateDJScript(context: context)
                print("🤖 [AI DJ] Generated Script: \(script)")
                DJVoiceManager.shared.speak(text: script)
            } catch {
                print("❌ [DJTriggerManager] Failed to generate DJ script: \(error.localizedDescription)")
            }
        }
    }
}
