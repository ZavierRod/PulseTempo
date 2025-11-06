//
//  PulseTempoApp.swift
//  PulseTempo
//
//  Created by Zavier Rodrigues on 11/4/25.
//

import SwiftUI

@main
struct PulseTempoApp: App {
    var body: some Scene {
        WindowGroup {
            AppCoordinator()
        }
    }
}

/// Coordinates navigation between onboarding and main app
struct AppCoordinator: View {
    @State private var hasCompletedOnboarding = false
    
    var body: some View {
        if hasCompletedOnboarding {
            // Main app view
            ActiveRunView()
        } else {
            // Onboarding flow
            WelcomeView {
                // When user taps "Get Started", move to main app
                withAnimation {
                    hasCompletedOnboarding = true
                }
            }
        }
    }
}
