//
//  PulseTempo_Watch_AppApp.swift
//  PulseTempo Watch App Watch App
//
//  Created by Zavier Rodrigues on 1/19/26.
//
//  App entry point - initializes and wires up all managers.
//

import SwiftUI

@main
struct PulseTempo_Watch_App_Watch_AppApp: App {
    
    // Create managers as StateObjects so they persist for app lifetime
    @StateObject private var workoutManager = WorkoutManager()
    @StateObject private var connectivityManager = PhoneConnectivityManager()
    
    init() {
        // Activate WatchConnectivity early so it's ready when user taps Start
        // Note: We access the shared instance here since StateObject isn't available in init
        // The actual connectivityManager will be activated in onAppear
        print("📱 [Watch] App launching, will activate WatchConnectivity...")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView(
                workoutManager: workoutManager,
                connectivityManager: connectivityManager
            )
            .onAppear {
                // Wire up the managers and activate connectivity immediately
                workoutManager.phoneConnectivityManager = connectivityManager
                connectivityManager.activate()
                print("📱 [Watch] WatchConnectivity activated on app appear")
            }
        }
    }
}
