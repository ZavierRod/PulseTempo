//
//  ContentView.swift
//  PulseTempo Watch App Watch App
//
//  Created by Zavier Rodrigues on 1/19/26.
//
//  Main UI for the PulseTempo Watch App.
//  Displays heart rate, cadence, and workout controls.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var workoutManager: WorkoutManager
    @ObservedObject var connectivityManager: PhoneConnectivityManager
    
    var body: some View {
        VStack(spacing: 4) {
            switch workoutManager.syncState {
            case .idle:
                preWorkoutView
            case .waitingForPhone:
                waitingForPhoneView
            case .pendingPhoneRequest:
                pendingPhoneRequestView
            case .active, .stopping:
                activeWorkoutView
            }
        }
    }
    
    // MARK: - Pre-Workout View
    
    private var preWorkoutView: some View {
        VStack(spacing: 8) {
            Image(systemName: "figure.run")
                .font(.title)
                .foregroundColor(.green)
            
            Text("PulseTempo")
                .font(.caption)
            
            Button("Start") {
                workoutManager.requestWorkoutStart()
            }
            .tint(.green)
        }
    }
    
    // MARK: - Waiting for Phone View
    
    private var waitingForPhoneView: some View {
        VStack(spacing: 8) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Waiting...")
                .font(.headline)
            
            HStack(spacing: 4) {
                Image(systemName: "iphone")
                    .foregroundColor(.blue)
                Text("Open iPhone")
                    .font(.caption2)
            }
            
            Text("to start workout")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Button("Cancel") {
                workoutManager.cancelWaiting()
            }
            .tint(.red)
            .padding(.top, 4)
        }
    }
    
    // MARK: - Pending Phone Request View
    
    private var pendingPhoneRequestView: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "iphone")
                    .foregroundColor(.blue)
                Image(systemName: "arrow.right")
                    .foregroundColor(.secondary)
                    .font(.caption2)
                Image(systemName: "applewatch")
                    .foregroundColor(.green)
            }
            .font(.title3)
            
            Text("Start Workout?")
                .font(.headline)
            
            Text("iPhone is ready")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Button("Start") {
                workoutManager.acceptPhoneRequest()
            }
            .tint(.green)
            .padding(.top, 4)
            
            Button("Cancel") {
                workoutManager.declinePhoneRequest()
            }
            .tint(.red)
        }
    }
    
    // MARK: - Active Workout View
    
    private var activeWorkoutView: some View {
        VStack(spacing: 4) {
            Text(workoutManager.elapsedTimeString)
                .font(.caption2)
            
            Text("\(Int(workoutManager.heartRate))")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.red)
            
            Text("BPM")
                .font(.caption2)
            
            HStack {
                Image(systemName: "figure.run")
                    .foregroundColor(.cyan)
                Text("\(Int(workoutManager.cadence)) SPM")
                    .foregroundColor(.cyan)
            }
            .font(.caption2)
            
            Button("Stop") {
                workoutManager.stopWorkout()
            }
            .tint(.red)
        }
    }
}

#Preview {
    ContentView(
        workoutManager: WorkoutManager(),
        connectivityManager: PhoneConnectivityManager()
    )
}
