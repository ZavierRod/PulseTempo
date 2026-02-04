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
        Group {
            switch workoutManager.syncState {
            case .idle:
                preWorkoutView
            case .waitingForPhone:
                waitingForPhoneView
            case .pendingPhoneRequest:
                pendingPhoneRequestView
            case .active, .paused:
                workoutTabView
            case .confirmingDiscard:
                discardConfirmationView
            case .showingSummary:
                summaryView
            case .stopping:
                // Brief stopping state - show loading
                VStack {
                    ProgressView()
                    Text("Saving...")
                        .font(.bebasNeueCaption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Pre-Workout View
    
    private var preWorkoutView: some View {
        VStack(spacing: 8) {
            Image(systemName: "figure.run")
                .font(.bebasNeueTitle)
                .foregroundColor(.green)
            
            Text("PulseTempo")
                .font(.bebasNeueCaption)
            
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
                .font(.bebasNeueTitle)
            
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
                .font(.bebasNeueTitle)
            
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
    
    // MARK: - Workout Tab View (Swipe Navigation)
    
    private var workoutTabView: some View {
        TabView {
            // Page 1: Metrics View
            metricsView
            
            // Page 2: Controls View
            controlsView
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
    }
    
    // MARK: - Metrics View (Page 1)
    
    private var metricsView: some View {
        VStack(spacing: 4) {
            // Paused indicator (only when paused)
            if workoutManager.syncState == .paused {
                HStack(spacing: 4) {
                    Image(systemName: "pause.fill")
                        .font(.caption2)
                    Text("PAUSED")
                        .font(.caption2)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.orange)
                .padding(.bottom, 2)
            }
            
            // Elapsed time
            Text(workoutManager.elapsedTimeString)
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .foregroundColor(workoutManager.syncState == .paused ? .orange : .primary)
            
            // Heart rate (big number)
            Text("\(Int(workoutManager.heartRate))")
                .font(.system(size: 44, weight: .bold))
                .foregroundColor(.red)
            
            Text("BPM")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            // Cadence
            HStack(spacing: 4) {
                Image(systemName: "figure.run")
                    .foregroundColor(.cyan)
                Text("\(Int(workoutManager.cadence)) SPM")
                    .foregroundColor(.cyan)
            }
            .font(.bebasNeueCaption)
            
            Spacer()
            
            // Swipe hint arrow
            HStack {
                Spacer()
                Image(systemName: "chevron.left")
                    .font(.bebasNeueCaption)
                    .foregroundColor(.secondary.opacity(0.6))
            }
            .padding(.trailing, 8)
            .padding(.bottom, 4)
        }
        .padding(.top, 8)
    }
    
    // MARK: - Controls View (Page 2)
    
    private var controlsView: some View {
        VStack(spacing: 12) {
            // Finish button (green)
            Button(action: {
                workoutManager.finishWorkout()
            }) {
                HStack {
                    Image(systemName: "flag.checkered")
                    Text("Finish")
                }
                .frame(maxWidth: .infinity)
            }
            .tint(.green)
            .buttonStyle(.borderedProminent)
            
            // Pause/Resume button (grey when pause, green when resume)
            if workoutManager.syncState == .paused {
                Button(action: {
                    workoutManager.resumeWorkout()
                }) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Resume")
                    }
                    .frame(maxWidth: .infinity)
                }
                .tint(.green)
                .buttonStyle(.borderedProminent)
            } else {
                Button(action: {
                    workoutManager.pauseWorkout()
                }) {
                    HStack {
                        Image(systemName: "pause.fill")
                        Text("Pause")
                    }
                    .frame(maxWidth: .infinity)
                }
                .tint(.gray)
                .buttonStyle(.borderedProminent)
            }
            
            // Stop button (red) - shows confirmation
            Button(action: {
                workoutManager.showDiscardConfirmation()
            }) {
                HStack {
                    Image(systemName: "xmark")
                    Text("Stop")
                }
                .frame(maxWidth: .infinity)
            }
            .tint(.red)
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 8)
    }
    
    // MARK: - Discard Confirmation View
    
    private var discardConfirmationView: some View {
        VStack(spacing: 12) {
            Text("Discard Workout?")
                .font(.bebasNeueTitle)
            
            Text("This cannot be undone.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            // Discard button (red)
            Button(action: {
                workoutManager.discardWorkout()
            }) {
                HStack {
                    Image(systemName: "trash.fill")
                    Text("Discard")
                }
                .frame(maxWidth: .infinity)
            }
            .tint(.red)
            .buttonStyle(.borderedProminent)
            
            // Cancel button (grey)
            Button(action: {
                workoutManager.cancelDiscard()
            }) {
                HStack {
                    Image(systemName: "arrow.left")
                    Text("Cancel")
                }
                .frame(maxWidth: .infinity)
            }
            .tint(.gray)
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 8)
    }
    
    // MARK: - Summary View
    
    private var summaryView: some View {
        VStack(spacing: 8) {
            // Header
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Complete")
                    .font(.bebasNeueTitle)
            }
            
            // Total time
            Text(workoutManager.elapsedTimeString)
                .font(.system(size: 28, weight: .bold, design: .monospaced))
            
            // Average heart rate
            HStack(spacing: 4) {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                Text("\(workoutManager.averageHeartRate) avg BPM")
                    .font(.bebasNeueCaption)
            }
            
            // Average cadence
            HStack(spacing: 4) {
                Image(systemName: "figure.run")
                    .foregroundColor(.cyan)
                Text("\(workoutManager.averageCadence) avg SPM")
                    .font(.bebasNeueCaption)
            }
            
            Spacer()
            
            // Home button (green)
            Button(action: {
                workoutManager.dismissSummary()
            }) {
                HStack {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
                .frame(maxWidth: .infinity)
            }
            .tint(.green)
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }
}

#Preview {
    ContentView(
        workoutManager: WorkoutManager(),
        connectivityManager: PhoneConnectivityManager()
    )
}
