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
            if workoutManager.isWorkoutActive {
                activeWorkoutView
            } else {
                preWorkoutView
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
                workoutManager.startWorkout()
            }
            .tint(.green)
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
