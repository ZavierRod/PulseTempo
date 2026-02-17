//
//  PhoneConnectivityManager.swift
//  PulseTempo Watch App
//
//  Created on 1/19/26.
//
//  Manages WatchConnectivity communication from Watch to iPhone.
//  Sends heart rate and cadence data in real-time during workouts.
//

import Foundation
import WatchConnectivity
import Combine

/// Manages communication from Apple Watch to iPhone via WatchConnectivity
class PhoneConnectivityManager: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    /// Whether the iPhone is reachable
    @Published var isPhoneReachable: Bool = false
    
    /// Connection status message for UI
    @Published var connectionStatus: String = "Not connected"
    
    /// Whether the session is activated and ready
    @Published var isSessionActivated: Bool = false
    
    /// BPM Lock state (synced from iPhone)
    @Published var isBPMLocked: Bool = false
    @Published var lockedBPMValue: Int?
    
    // MARK: - Private Properties
    
    private var session: WCSession?
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        // Don't setup session here - call activate() when ready
    }
    
    /// Call this to activate WatchConnectivity
    func activate() {
        setupSession()
    }
    
    // MARK: - Session Setup
    
    /// Initialize and activate WatchConnectivity session
    private func setupSession() {
        guard WCSession.isSupported() else {
            print("❌ [Watch] WatchConnectivity not supported")
            connectionStatus = "Not supported"
            return
        }
        
        session = WCSession.default
        session?.delegate = self
        session?.activate()
        print("📱 [Watch] WatchConnectivity session activating...")
    }
    
    // MARK: - Send Data to iPhone
    
    /// Send heart rate and cadence data to iPhone
    /// - Parameters:
    ///   - heartRate: Current heart rate in BPM
    ///   - cadence: Current running cadence in SPM (steps per minute)
    func sendHeartRate(_ heartRate: Double, cadence: Double = 0) {
        guard let session = session, session.isReachable else {
            print("⚠️ [Watch] iPhone not reachable, cannot send HR")
            return
        }
        
        let message: [String: Any] = [
            "type": "heartRate",
            "bpm": heartRate,
            "cadence": cadence,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        session.sendMessage(message, replyHandler: nil) { error in
            print("❌ [Watch] Failed to send heart rate: \(error.localizedDescription)")
        }
        
        print("📤 [Watch] Sent HR: \(Int(heartRate)) BPM, Cadence: \(Int(cadence)) SPM")
    }
    
    /// Send workout state change to iPhone
    /// - Parameters:
    ///   - isActive: Whether workout is currently active
    ///   - isPaused: Whether workout is currently paused (default: false)
    ///   - wasFinished: Whether workout was finished/saved (vs discarded) - only relevant when isActive is false
    func sendWorkoutState(isActive: Bool, isPaused: Bool = false, wasFinished: Bool = false) {
        guard let session = session, session.isReachable else {
            print("⚠️ [Watch] iPhone not reachable, cannot send workout state")
            return
        }
        
        let message: [String: Any] = [
            "type": "workoutState",
            "isActive": isActive,
            "isPaused": isPaused,
            "wasFinished": wasFinished,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        session.sendMessage(message, replyHandler: nil) { error in
            print("❌ [Watch] Failed to send workout state: \(error.localizedDescription)")
        }
        
        let stateDescription: String
        if !isActive {
            stateDescription = wasFinished ? "FINISHED" : "DISCARDED"
        } else if isPaused {
            stateDescription = "PAUSED"
        } else {
            stateDescription = "ACTIVE"
        }
        print("📤 [Watch] Sent workout state: \(stateDescription)")
    }
    
    /// Send dismiss summary command to iPhone
    func sendDismissSummaryCommand() {
        guard let session = session, session.isReachable else {
            print("⚠️ [Watch] iPhone not reachable, cannot send dismiss summary")
            return
        }
        
        let message: [String: Any] = [
            "type": "command",
            "action": "dismissSummary",
            "timestamp": Date().timeIntervalSince1970
        ]
        
        session.sendMessage(message, replyHandler: nil) { error in
            print("❌ [Watch] Failed to send dismiss summary: \(error.localizedDescription)")
        }
        
        print("📤 [Watch] Sent dismiss summary command to iPhone")
    }
    
    /// Send toggle BPM lock command to iPhone
    func sendToggleBPMLockCommand() {
        guard let session = session, session.isReachable else {
            print("⚠️ [Watch] iPhone not reachable, cannot toggle BPM lock")
            return
        }
        
        let message: [String: Any] = [
            "type": "command",
            "action": "toggleBPMLock",
            "timestamp": Date().timeIntervalSince1970
        ]
        
        session.sendMessage(message, replyHandler: nil) { error in
            print("❌ [Watch] Failed to send BPM lock toggle: \(error.localizedDescription)")
        }
        
        print("📤 [Watch] Sent toggle BPM lock command to iPhone")
    }
    
    // MARK: - Workout Request (Bidirectional Sync)
    
    /// Send workout request to iPhone (instant if reachable)
    func sendWorkoutRequest() {
        guard let session = session, session.isReachable else {
            print("⚠️ [Watch] iPhone not reachable for workout request")
            return
        }
        
        let message: [String: Any] = [
            "type": "workoutRequest",
            "action": "start",
            "timestamp": Date().timeIntervalSince1970
        ]
        
        session.sendMessage(message, replyHandler: nil) { error in
            print("❌ [Watch] Failed to send workout request: \(error.localizedDescription)")
        }
        
        print("📤 [Watch] Sent workout request to iPhone")
    }
    
    /// Send workout request via applicationContext (fallback when phone not reachable)
    func sendWorkoutRequestWithContext() {
        guard let session = session else {
            print("❌ [Watch] No session for applicationContext")
            return
        }
        
        // Only try if session is activated
        guard session.activationState == .activated else {
            print("⚠️ [Watch] Session not activated yet, will retry via context when activated")
            // Store pending request to send when session activates
            pendingContextRequest = true
            return
        }
        
        let context: [String: Any] = [
            "pendingWorkoutRequest": true,
            "requestTimestamp": Date().timeIntervalSince1970
        ]
        
        do {
            try session.updateApplicationContext(context)
            print("📤 [Watch] Sent workout request via applicationContext")
        } catch {
            print("❌ [Watch] Failed to update applicationContext: \(error.localizedDescription)")
        }
    }
    
    /// Flag for pending context request (when session wasn't ready)
    private var pendingContextRequest: Bool = false
    
    /// Clear pending workout request from applicationContext
    func clearPendingWorkoutContext() {
        // Clear the pending flag
        pendingContextRequest = false
        
        guard let session = session, session.activationState == .activated else {
            print("⚠️ [Watch] Session not activated, just cleared pending flag")
            return
        }
        
        do {
            try session.updateApplicationContext([:])
            print("🧹 [Watch] Cleared pending workout context")
        } catch {
            print("❌ [Watch] Failed to clear applicationContext: \(error.localizedDescription)")
        }
    }
}

// MARK: - WCSessionDelegate

extension PhoneConnectivityManager: WCSessionDelegate {
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            switch activationState {
            case .activated:
                self.connectionStatus = "Connected"
                self.isPhoneReachable = session.isReachable
                self.isSessionActivated = true
                print("✅ [Watch] WatchConnectivity activated, iPhone reachable: \(session.isReachable)")
                
                // Send any pending context request now that session is ready
                if self.pendingContextRequest {
                    self.pendingContextRequest = false
                    self.sendWorkoutRequestWithContext()
                }
                
                // Check for pending workout request from phone
                // Small delay to ensure WorkoutManager's notification observer is ready
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.checkPendingPhoneWorkoutRequest()
                }
            case .inactive:
                self.connectionStatus = "Inactive"
                self.isPhoneReachable = false
                self.isSessionActivated = false
                print("⚠️ [Watch] WatchConnectivity inactive")
            case .notActivated:
                self.connectionStatus = "Not activated"
                self.isPhoneReachable = false
                self.isSessionActivated = false
                print("❌ [Watch] WatchConnectivity not activated")
            @unknown default:
                self.connectionStatus = "Unknown"
                self.isPhoneReachable = false
                self.isSessionActivated = false
            }
        }
        
        if let error = error {
            print("❌ [Watch] WatchConnectivity activation error: \(error.localizedDescription)")
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isPhoneReachable = session.isReachable
            self.connectionStatus = session.isReachable ? "Connected" : "iPhone not reachable"
            print("📱 [Watch] iPhone reachability changed: \(session.isReachable)")
        }
    }
    
    /// Handle messages received from iPhone (e.g., commands to start/stop workout)
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        print("📥 [Watch] Received message from iPhone: \(message)")
        
        guard let type = message["type"] as? String else { return }
        
        switch type {
        case "command":
            if let action = message["action"] as? String {
                handleCommand(action)
            }
        case "workoutRequest":
            // iPhone is requesting watch to start workout
            if let action = message["action"] as? String, action == "start" {
                handleWorkoutRequestFromPhone()
            }
        case "nowPlaying":
            // Could display current track info on watch (future enhancement)
            if let title = message["title"] as? String {
                print("🎵 [Watch] Now playing: \(title)")
            }
        case "bpmLockState":
            handleBPMLockStateMessage(message)
        default:
            print("⚠️ [Watch] Unknown message type: \(type)")
        }
    }
    
    /// Handle workout request from iPhone
    private func handleWorkoutRequestFromPhone() {
        print("📲 [Watch] Received workout request from iPhone")
        
        // Post notification so WorkoutManager can start the workout
        NotificationCenter.default.post(
            name: Notification.Name("PhoneWorkoutRequest"),
            object: nil,
            userInfo: ["source": "phone"]
        )
    }
    
    /// Check if there's a pending workout request from phone in applicationContext
    func hasPendingPhoneWorkoutRequest() -> Bool {
        guard let session = session, session.activationState == .activated else { return false }
        
        let context = session.receivedApplicationContext
        
        if let pendingRequest = context["pendingWorkoutRequest"] as? Bool,
           pendingRequest,
           let source = context["source"] as? String,
           source == "phone" {
            return true
        }
        return false
    }
    
    /// Check applicationContext for pending workout request from phone (on app launch)
    func checkPendingPhoneWorkoutRequest() {
        guard let session = session, session.activationState == .activated else { return }
        
        let context = session.receivedApplicationContext
        
        if let pendingRequest = context["pendingWorkoutRequest"] as? Bool,
           pendingRequest,
           let source = context["source"] as? String,
           source == "phone" {
            print("📲 [Watch] Found pending workout request from phone in applicationContext")
            handleWorkoutRequestFromPhone()
        }
    }
    
    /// Handle commands from iPhone
    private func handleCommand(_ action: String) {
        print("🎮 [Watch] Received command: \(action)")
        
        // Post notification so WorkoutManager can respond
        NotificationCenter.default.post(
            name: Notification.Name("PhoneCommand"),
            object: nil,
            userInfo: ["action": action]
        )
    }
    
    /// Handle BPM lock state update from iPhone
    private func handleBPMLockStateMessage(_ message: [String: Any]) {
        guard let isLocked = message["isLocked"] as? Bool else { return }
        let lockedValue = message["lockedValue"] as? Int
        
        DispatchQueue.main.async {
            self.isBPMLocked = isLocked
            self.lockedBPMValue = lockedValue
        }
        
        let status = isLocked ? "LOCKED at \(lockedValue ?? 0)" : "UNLOCKED"
        print("🔒 [Watch] BPM lock state updated: \(status)")
    }
}
