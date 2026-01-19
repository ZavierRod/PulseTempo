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
    /// - Parameter isActive: Whether workout is currently active
    func sendWorkoutState(isActive: Bool) {
        guard let session = session, session.isReachable else {
            print("⚠️ [Watch] iPhone not reachable, cannot send workout state")
            return
        }
        
        let message: [String: Any] = [
            "type": "workoutState",
            "isActive": isActive,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        session.sendMessage(message, replyHandler: nil) { error in
            print("❌ [Watch] Failed to send workout state: \(error.localizedDescription)")
        }
        
        print("📤 [Watch] Sent workout state: \(isActive ? "STARTED" : "STOPPED")")
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
                print("✅ [Watch] WatchConnectivity activated, iPhone reachable: \(session.isReachable)")
            case .inactive:
                self.connectionStatus = "Inactive"
                self.isPhoneReachable = false
                print("⚠️ [Watch] WatchConnectivity inactive")
            case .notActivated:
                self.connectionStatus = "Not activated"
                self.isPhoneReachable = false
                print("❌ [Watch] WatchConnectivity not activated")
            @unknown default:
                self.connectionStatus = "Unknown"
                self.isPhoneReachable = false
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
        case "nowPlaying":
            // Could display current track info on watch (future enhancement)
            if let title = message["title"] as? String {
                print("🎵 [Watch] Now playing: \(title)")
            }
        default:
            print("⚠️ [Watch] Unknown message type: \(type)")
        }
    }
    
    /// Handle commands from iPhone
    private func handleCommand(_ action: String) {
        print("🎮 [Watch] Received command: \(action)")
        // Commands like "startWorkout" or "stopWorkout" could be handled here
        // For now, workout is controlled from watch UI
        
        // Post notification so WorkoutManager can respond if needed
        NotificationCenter.default.post(
            name: Notification.Name("PhoneCommand"),
            object: nil,
            userInfo: ["action": action]
        )
    }
}
