//
//  WearableDeviceManager.swift
//  PulseTempo
//
//  Created by Antigravity on 12/12/24.
//

import Foundation
import Combine
import WatchConnectivity

/// Manages the user's selected wearable device and persists the preference
@MainActor
class WearableDeviceManager: ObservableObject {
    // MARK: - Published Properties
    
    /// The currently selected wearable device
    @Published var selectedDevice: WearableDevice {
        didSet {
            saveDevicePreference()
        }
    }
    
    /// Whether an Apple Watch is currently paired with this iPhone
    @Published var isAppleWatchPaired: Bool = false
    
    // MARK: - Private Properties
    
    private let userDefaultsKey = "selectedWearableDevice"
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        // Load saved preference or default to demo mode
        self.selectedDevice = Self.loadDevicePreference()
        
        // Check for Apple Watch pairing
        self.detectAppleWatchPairing()
    }
    
    // MARK: - Public Methods
    
    /// Save the current device preference to UserDefaults
    func saveDevicePreference() {
        UserDefaults.standard.set(selectedDevice.rawValue, forKey: userDefaultsKey)
    }
    
    /// Load device preference from UserDefaults
    static func loadDevicePreference() -> WearableDevice {
        guard let savedValue = UserDefaults.standard.string(forKey: "selectedWearableDevice"),
              let device = WearableDevice(rawValue: savedValue) else {
            return .demoMode // Default to demo mode if no preference saved
        }
        return device
    }
    
    /// Update the selected device and save preference
    func selectDevice(_ device: WearableDevice) {
        selectedDevice = device
    }
    
    /// Check if the selected device is properly configured
    func isDeviceConfigured() -> Bool {
        switch selectedDevice {
        case .appleWatch:
            return isAppleWatchPaired
        case .garminVenu3S:
            // For Garmin, we trust that if they selected it, they've set it up
            // In the future, we could check if Garmin Connect is installed
            return true
        case .demoMode:
            return true
        }
    }
    
    /// Get a user-friendly status message for the current device
    func getDeviceStatusMessage() -> String {
        switch selectedDevice {
        case .appleWatch:
            return isAppleWatchPaired ? "Apple Watch connected" : "Apple Watch not paired"
        case .garminVenu3S:
            return "Using Garmin Venu 3S via Health Sync"
        case .demoMode:
            return "Simulated heart rate active"
        }
    }
    
    /// Reset to demo mode (useful for testing or troubleshooting)
    func resetToDemo() {
        selectedDevice = .demoMode
    }
    
    // MARK: - Private Methods
    
    /// Detect if an Apple Watch is paired with this iPhone
    private func detectAppleWatchPairing() {
        #if !targetEnvironment(simulator)
        // WatchConnectivity is only available on real devices
        if WCSession.isSupported() {
            let session = WCSession.default
            isAppleWatchPaired = session.isPaired
            
            // Note: We could set up a delegate to monitor pairing changes,
            // but for MVP, we just check at initialization
        }
        #else
        // On simulator, we can't detect real watch pairing
        isAppleWatchPaired = false
        #endif
    }
    
    /// Check if Garmin Connect app is installed (optional future enhancement)
    private func isGarminConnectInstalled() -> Bool {
        // This would require checking if URL scheme "garminconnect://" can be opened
        // We can implement this in a future version if needed
        return true // Assume installed for now
    }
}

// MARK: - Convenience Extensions

extension WearableDeviceManager {
    /// Whether the current device requires HealthKit permissions
    var requiresHealthKit: Bool {
        // All devices use HealthKit except pure demo mode
        // Even demo mode might want HealthKit for future features
        return true
    }
    
    /// Whether the current device can provide real-time heart rate
    var providesRealTimeHeartRate: Bool {
        switch selectedDevice {
        case .appleWatch, .garminVenu3S:
            return true
        case .demoMode:
            return false // Demo is simulated
        }
    }
}
