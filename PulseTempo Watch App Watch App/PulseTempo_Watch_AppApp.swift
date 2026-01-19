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
    
    var body: some Scene {
        WindowGroup {
            ContentView(
                workoutManager: workoutManager,
                connectivityManager: connectivityManager
            )
            .onAppear {
                workoutManager.phoneConnectivityManager = connectivityManager
            }
        }
    }
}
