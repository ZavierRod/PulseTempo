//
//  WearableDevice.swift
//  PulseTempo
//
//  Created by Antigravity on 12/12/24.
//

import Foundation
import SwiftUI

/// Represents the wearable device options for heart rate monitoring
enum WearableDevice: String, Codable, CaseIterable, Identifiable {
    case appleWatch = "Apple Watch"
    case garminVenu3S = "Garmin Venu 3S"
    case demoMode = "Demo Mode"
    
    var id: String { rawValue }
    
    /// SF Symbol icon name for the device
    var iconName: String {
        switch self {
        case .appleWatch:
            return "applewatch"
        case .garminVenu3S:
            return "figure.run"
        case .demoMode:
            return "gamecontroller.fill"
        }
    }
    
    /// Color theme for the device
    var color: Color {
        switch self {
        case .appleWatch:
            return .blue
        case .garminVenu3S:
            return .green
        case .demoMode:
            return .orange
        }
    }
    
    /// Short description of the device
    var description: String {
        switch self {
        case .appleWatch:
            return "Real-time heart rate from Apple Watch"
        case .garminVenu3S:
            return "Heart rate synced via Garmin Connect"
        case .demoMode:
            return "Simulated heart rate for testing"
        }
    }
    
    /// Setup instructions for the device
    var setupInstructions: [String] {
        switch self {
        case .appleWatch:
            return [
                "Pair your Apple Watch with this iPhone",
                "Grant HealthKit permissions in the next step",
                "Wear your Apple Watch during workouts"
            ]
        case .garminVenu3S:
            return [
                "Install the Garmin Connect app",
                "Pair your Garmin Venu 3S",
                "Open Garmin Connect Settings → Health Sync",
                "Enable 'Sync to Apple Health'",
                "Grant permissions for Heart Rate data",
                "Grant HealthKit permissions in the next step"
            ]
        case .demoMode:
            return [
                "No wearable device required",
                "Heart rate will be simulated during workouts",
                "Perfect for testing the app"
            ]
        }
    }
    
    /// Whether this device requires external app setup
    var requiresExternalApp: Bool {
        switch self {
        case .appleWatch, .demoMode:
            return false
        case .garminVenu3S:
            return true
        }
    }
    
    /// Name of the external app required (if any)
    var externalAppName: String? {
        switch self {
        case .appleWatch, .demoMode:
            return nil
        case .garminVenu3S:
            return "Garmin Connect"
        }
    }
    
    /// App Store link for the external app (if any)
    var externalAppStoreURL: URL? {
        switch self {
        case .appleWatch, .demoMode:
            return nil
        case .garminVenu3S:
            return URL(string: "https://apps.apple.com/us/app/garmin-connect/id583446403")
        }
    }
    
    /// Expected latency for heart rate data
    var expectedLatency: String {
        switch self {
        case .appleWatch:
            return "< 1 second"
        case .garminVenu3S:
            return "1-3 seconds"
        case .demoMode:
            return "Real-time"
        }
    }
}
