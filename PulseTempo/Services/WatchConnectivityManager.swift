//
//  WatchConnectivityManager.swift
//  PulseTempo
//
//  Created on 1/19/26.
//
//  Receives heart rate and cadence data from Apple Watch via WatchConnectivity.
//  Publishes values for use by HeartRateService and other components.
//

import Foundation
import WatchConnectivity
import Combine

/// Manages communication from Apple Watch to iPhone via WatchConnectivity
class WatchConnectivityManager: NSObject, ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = WatchConnectivityManager()
    
    // MARK: - Published Properties
    
    /// Current heart rate received from watch (BPM)
    @Published var heartRate: Double = 0
    
    /// Current cadence received from watch (SPM)
    @Published var cadence: Double = 0
    
    /// Whether the watch is reachable
    @Published var isWatchReachable: Bool = false
    
    /// Whether a workout is active on the watch
    @Published var isWatchWorkoutActive: Bool = false
    
    /// Whether the watch workout is paused
    @Published var isWatchWorkoutPaused: Bool = false
    
    /// Whether the watch workout just finished (for showing summary)
    @Published var didWatchWorkoutFinish: Bool = false
    
    /// Connection status message for debugging
    @Published var connectionStatus: String = "Not connected"
    
    /// Whether there's a pending workout request from watch
    @Published var hasPendingWorkoutRequest: Bool = false
    
    /// Whether iPhone is waiting for watch to start workout
    @Published var isWaitingForWatch: Bool = false
    
    /// Callback when workout should start (triggered by watch request)
    var onWorkoutRequestReceived: (() -> Void)?
    
    /// Callback when watch confirms workout started
    var onWatchWorkoutStarted: (() -> Void)?
    
    /// Callback when watch pauses workout
    var onWatchWorkoutPaused: (() -> Void)?
    
    /// Callback when watch resumes workout
    var onWatchWorkoutResumed: (() -> Void)?
    
    /// Callback when watch finishes workout (saved)
    var onWatchWorkoutFinished: (() -> Void)?
    
    /// Callback when watch discards workout (not saved)
    var onWatchWorkoutDiscarded: (() -> Void)?
    
    /// Callback when watch dismisses summary and returns to home
    var onWatchSummaryDismissed: (() -> Void)?
    
    /// Callback when watch requests BPM lock toggle
    var onWatchToggleBPMLock: (() -> Void)?
    
    /// Timestamp of last received heart rate
    @Published var lastHeartRateUpdate: Date?
    
    // MARK: - Private Properties
    
    private var session: WCSession?
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
    }
    
    // MARK: - Session Setup
    
    /// Activate WatchConnectivity session - call this on app launch
    func activate() {
        guard WCSession.isSupported() else {
            print("❌ [iOS] WatchConnectivity not supported")
            connectionStatus = "Not supported"
            return
        }
        
        session = WCSession.default
        session?.delegate = self
        session?.activate()
        print("📱 [iOS] WatchConnectivity session activating...")
    }
    
    // MARK: - Send Commands to Watch
    
    /// Send a command to start workout on watch
    func sendStartWorkoutCommand() {
        sendCommand("startWorkout")
    }
    
    /// Send a command to stop workout on watch
    func sendStopWorkoutCommand() {
        sendCommand("stopWorkout")
    }
    
    /// Send a command to pause workout on watch
    func sendPauseWorkoutCommand() {
        sendCommand("pauseWorkout")
    }
    
    /// Send a command to resume workout on watch
    func sendResumeWorkoutCommand() {
        sendCommand("resumeWorkout")
    }
    
    /// Send a command to finish workout on watch (save to HealthKit)
    func sendFinishWorkoutCommand() {
        sendCommand("finishWorkout")
    }
    
    /// Send a command to discard workout on watch (don't save)
    func sendDiscardWorkoutCommand() {
        sendCommand("discardWorkout")
    }
    
    /// Send a command to dismiss summary and go home on watch
    func sendDismissSummaryCommand() {
        sendCommand("dismissSummary")
    }
    
    /// Send now playing info to watch
    func sendNowPlaying(title: String, artist: String) {
        guard let session = session, session.isReachable else {
            print("⚠️ [iOS] Watch not reachable, cannot send now playing")
            return
        }
        
        let message: [String: Any] = [
            "type": "nowPlaying",
            "title": title,
            "artist": artist
        ]
        
        session.sendMessage(message, replyHandler: nil) { error in
            print("❌ [iOS] Failed to send now playing: \(error.localizedDescription)")
        }
    }
    
    /// Send BPM lock state to watch (so watch UI stays in sync)
    func sendBPMLockState(isLocked: Bool, lockedValue: Int?) {
        guard let session = session, session.isReachable else {
            print("⚠️ [iOS] Watch not reachable, cannot send BPM lock state")
            return
        }
        
        var message: [String: Any] = [
            "type": "bpmLockState",
            "isLocked": isLocked
        ]
        if let value = lockedValue {
            message["lockedValue"] = value
        }
        
        session.sendMessage(message, replyHandler: nil) { error in
            print("❌ [iOS] Failed to send BPM lock state: \(error.localizedDescription)")
        }
    }
    
    /// Send a command to the watch
    private func sendCommand(_ action: String) {
        guard let session = session, session.isReachable else {
            print("⚠️ [iOS] Watch not reachable, cannot send command: \(action)")
            return
        }
        
        let message: [String: Any] = [
            "type": "command",
            "action": action
        ]
        
        session.sendMessage(message, replyHandler: nil) { error in
            print("❌ [iOS] Failed to send command: \(error.localizedDescription)")
        }
        
        print("📤 [iOS] Sent command to watch: \(action)")
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            switch activationState {
            case .activated:
                self.connectionStatus = "Connected"
                self.isWatchReachable = session.isReachable
                print("✅ [iOS] WatchConnectivity activated, watch reachable: \(session.isReachable)")
                
                // Check for pending workout request in applicationContext
                self.checkPendingWorkoutRequest()
            case .inactive:
                self.connectionStatus = "Inactive"
                self.isWatchReachable = false
                print("⚠️ [iOS] WatchConnectivity inactive")
            case .notActivated:
                self.connectionStatus = "Not activated"
                self.isWatchReachable = false
                print("❌ [iOS] WatchConnectivity not activated")
            @unknown default:
                self.connectionStatus = "Unknown"
                self.isWatchReachable = false
            }
        }
        
        if let error = error {
            print("❌ [iOS] WatchConnectivity activation error: \(error.localizedDescription)")
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        DispatchQueue.main.async {
            self.connectionStatus = "Inactive"
            self.isWatchReachable = false
        }
        print("⚠️ [iOS] WatchConnectivity session became inactive")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        DispatchQueue.main.async {
            self.connectionStatus = "Deactivated"
            self.isWatchReachable = false
        }
        print("⚠️ [iOS] WatchConnectivity session deactivated")
        
        // Reactivate session
        session.activate()
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchReachable = session.isReachable
            self.connectionStatus = session.isReachable ? "Connected" : "Watch not reachable"
        }
        print("📱 [iOS] Watch reachability changed: \(session.isReachable)")
    }
    
    /// Handle messages received from Apple Watch
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        print("📥 [iOS] Received message from watch: \(message)")
        
        guard let type = message["type"] as? String else { return }
        
        switch type {
        case "heartRate":
            handleHeartRateMessage(message)
        case "workoutState":
            handleWorkoutStateMessage(message)
        case "workoutRequest":
            handleWorkoutRequestMessage(message)
        case "command":
            handleCommandMessage(message)
        default:
            print("⚠️ [iOS] Unknown message type: \(type)")
        }
    }
    
    /// Handle command messages from watch
    private func handleCommandMessage(_ message: [String: Any]) {
        guard let action = message["action"] as? String else { return }
        
        print("🎮 [iOS] Received command from watch: \(action)")
        
        DispatchQueue.main.async {
            switch action {
            case "dismissSummary":
                self.onWatchSummaryDismissed?()
            case "toggleBPMLock":
                self.onWatchToggleBPMLock?()
            default:
                print("⚠️ [iOS] Unknown command from watch: \(action)")
            }
        }
    }
    
    /// Process heart rate and cadence data from watch
    private func handleHeartRateMessage(_ message: [String: Any]) {
        guard let bpm = message["bpm"] as? Double else { return }
        let cadence = message["cadence"] as? Double ?? 0
        
        DispatchQueue.main.async {
            self.heartRate = bpm
            self.cadence = cadence
            self.lastHeartRateUpdate = Date()
        }
        
        print("💓 [iOS] Received from watch - HR: \(Int(bpm)) BPM, Cadence: \(Int(cadence)) SPM")
    }
    
    /// Process workout state changes from watch
    private func handleWorkoutStateMessage(_ message: [String: Any]) {
        guard let isActive = message["isActive"] as? Bool else { return }
        let isPaused = message["isPaused"] as? Bool ?? false
        let wasFinished = message["wasFinished"] as? Bool ?? false
        
        DispatchQueue.main.async {
            let wasActive = self.isWatchWorkoutActive
            let wasPaused = self.isWatchWorkoutPaused
            
            self.isWatchWorkoutActive = isActive
            self.isWatchWorkoutPaused = isPaused
            
            // If we were waiting for watch and it started, clear waiting state
            if isActive && !isPaused && self.isWaitingForWatch {
                self.isWaitingForWatch = false
                self.onWatchWorkoutStarted?()
                print("✅ [iOS] Watch confirmed workout started!")
            }
            
            // Handle pause state change
            if isActive && isPaused && !wasPaused {
                self.onWatchWorkoutPaused?()
                print("⏸ [iOS] Watch workout paused")
            }
            
            // Handle resume state change
            if isActive && !isPaused && wasPaused {
                self.onWatchWorkoutResumed?()
                print("▶️ [iOS] Watch workout resumed")
            }
            
            // Handle workout end
            if !isActive && wasActive {
                if wasFinished {
                    // Workout was finished (saved)
                    self.didWatchWorkoutFinish = true
                    self.onWatchWorkoutFinished?()
                    print("🏁 [iOS] Watch workout finished (saved)")
                } else {
                    // Workout was discarded (not saved)
                    self.onWatchWorkoutDiscarded?()
                    print("🗑 [iOS] Watch workout discarded")
                }
                
                // Reset values when workout ends
                self.heartRate = 0
                self.cadence = 0
                self.isWatchWorkoutPaused = false
            }
        }
        
        let stateDescription: String
        if !isActive {
            stateDescription = wasFinished ? "FINISHED" : "STOPPED"
        } else if isPaused {
            stateDescription = "PAUSED"
        } else {
            stateDescription = "ACTIVE"
        }
        print("🏃 [iOS] Watch workout state: \(stateDescription)")
    }
    
    // MARK: - Workout Request Handling (Bidirectional Sync)
    
    /// Process workout request from watch
    private func handleWorkoutRequestMessage(_ message: [String: Any]) {
        guard let action = message["action"] as? String, action == "start" else { return }
        
        print("📲 [iOS] Received workout request from watch")
        
        DispatchQueue.main.async {
            self.hasPendingWorkoutRequest = true
            
            // Post local notification to alert user
            NotificationService.shared.postWorkoutRequestNotification()
            
            // Call the callback if set
            self.onWorkoutRequestReceived?()
        }
    }
    
    /// Check applicationContext for pending workout request (on app launch)
    func checkPendingWorkoutRequest() {
        guard let session = session else { return }
        
        let context = session.receivedApplicationContext
        
        if let pendingRequest = context["pendingWorkoutRequest"] as? Bool, pendingRequest {
            print("📲 [iOS] Found pending workout request in applicationContext")
            
            DispatchQueue.main.async {
                self.hasPendingWorkoutRequest = true
                
                // Post notification
                NotificationService.shared.postWorkoutRequestNotification()
                
                // Call the callback if set
                self.onWorkoutRequestReceived?()
            }
            
            // Clear the context after handling
            clearReceivedWorkoutRequest()
        }
    }
    
    /// Clear the pending workout request
    func clearPendingWorkoutRequest() {
        DispatchQueue.main.async {
            self.hasPendingWorkoutRequest = false
        }
        clearReceivedWorkoutRequest()
        NotificationService.shared.clearWorkoutRequestNotifications()
        print("🧹 [iOS] Cleared pending workout request")
    }
    
    /// Clear received applicationContext
    private func clearReceivedWorkoutRequest() {
        // We can't directly clear receivedApplicationContext, but we can
        // send a confirmation back to watch which will clear their context
        // For now, just log it
        print("🧹 [iOS] Acknowledged workout request from context")
    }
    
    /// Send confirmation to watch that workout has started
    func sendWorkoutStartedConfirmation() {
        guard let session = session, session.isReachable else {
            print("⚠️ [iOS] Watch not reachable, cannot send confirmation")
            return
        }
        
        let message: [String: Any] = [
            "type": "command",
            "action": "startWorkout",
            "timestamp": Date().timeIntervalSince1970
        ]
        
        session.sendMessage(message, replyHandler: nil) { error in
            print("❌ [iOS] Failed to send workout confirmation: \(error.localizedDescription)")
        }
        
        print("📤 [iOS] Sent workout started confirmation to watch")
    }
    
    // MARK: - iPhone-Initiated Workout Request (Phone → Watch)
    
    /// Request workout start from iPhone - sends to watch and enters waiting state
    func requestWorkoutFromPhone() {
        DispatchQueue.main.async {
            self.isWaitingForWatch = true
        }
        
        // Try direct message first if watch is reachable
        if let session = session, session.isReachable {
            let message: [String: Any] = [
                "type": "workoutRequest",
                "action": "start",
                "source": "phone",
                "timestamp": Date().timeIntervalSince1970
            ]
            
            session.sendMessage(message, replyHandler: nil) { [weak self] error in
                print("❌ [iOS] Failed to send workout request: \(error.localizedDescription)")
                // Fall back to applicationContext
                self?.sendWorkoutRequestViaContext()
            }
            
            print("📤 [iOS] Sent workout request to watch via message")
        } else {
            // Watch not reachable - use applicationContext
            sendWorkoutRequestViaContext()
            print("⏳ [iOS] Watch not reachable, sent via applicationContext")
        }
    }
    
    /// Send workout request via applicationContext (fallback)
    private func sendWorkoutRequestViaContext() {
        guard let session = session else {
            print("❌ [iOS] No session for applicationContext")
            return
        }
        
        let context: [String: Any] = [
            "pendingWorkoutRequest": true,
            "source": "phone",
            "requestTimestamp": Date().timeIntervalSince1970
        ]
        
        do {
            try session.updateApplicationContext(context)
            print("📤 [iOS] Sent workout request via applicationContext")
        } catch {
            print("❌ [iOS] Failed to update applicationContext: \(error.localizedDescription)")
        }
    }
    
    /// Cancel waiting for watch
    func cancelWaitingForWatch() {
        DispatchQueue.main.async {
            self.isWaitingForWatch = false
        }
        
        // Clear the applicationContext
        guard let session = session else { return }
        
        do {
            try session.updateApplicationContext([:])
            print("🧹 [iOS] Cleared workout request from applicationContext")
        } catch {
            print("❌ [iOS] Failed to clear applicationContext: \(error.localizedDescription)")
        }
    }
}
