//
//  PulseTempoApp.swift
//  PulseTempo
//
//  Created by Zavier Rodrigues on 11/4/25.
//

import SwiftUI
import Foundation

@main
struct PulseTempoApp: App {
    init() {
        // Configure navigation bar appearance to fix text colors
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .clear
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.label]
        appearance.titleTextAttributes = [.foregroundColor: UIColor.label]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        
        // Activate WatchConnectivity to receive heart rate from Apple Watch
        WatchConnectivityManager.shared.activate()
        
        // Request notification permission for workout sync
        NotificationService.shared.requestPermission()
        
        // IMPORTANT: Warm up local network permission early
        // This triggers the iOS permission dialog before BPM analysis is actually needed,
        // ensuring the user has already granted permission by the time playlists are selected.
        MusicService.shared.warmUpLocalNetworkPermission()
    }
    
    var body: some Scene {
        WindowGroup {
            AppCoordinator()
        }
    }
}

/// Coordinates navigation between onboarding and main app
struct AppCoordinator: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    private let healthKitManager: HealthKitManager
    private let musicKitManager: MusicKitManager

    init(
        healthKitManager: HealthKitManager = .shared,
        musicKitManager: MusicKitManager = .shared
    ) {
        self.healthKitManager = healthKitManager
        self.musicKitManager = musicKitManager
    }

    private var shouldBypassOnboarding: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("SKIP_ONBOARDING")
        #else
        false
        #endif
    }

    var body: some View {
        Group {
            if hasCompletedOnboarding || shouldBypassOnboarding {
                // Main app view - Home Screen Dashboard
                HomeView()
            } else {
                // Onboarding flow
                OnboardingCoordinator(
                    healthKitManager: healthKitManager,
                    musicKitManager: musicKitManager,
                    onFinished: {
                        withAnimation {
                            hasCompletedOnboarding = true
                        }
                    }
                )
            }
        }
        .preferredColorScheme(.light) // Force light mode to fix text visibility
    }
}
