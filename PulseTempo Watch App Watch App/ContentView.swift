//
//  ContentView.swift
//  PulseTempo Watch App Watch App
//
//  Created by Zavier Rodrigues on 1/19/26.
//
//  Main UI for the PulseTempo Watch App.
//  Displays heart rate, cadence, and workout controls.
//  Visual language matches the iPhone app (gradient backgrounds, glass cards, zone coloring).
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
                ZStack {
                    WatchGradientBackground()
                    VStack(spacing: 8) {
                        ProgressView()
                            .tint(.white)
                        Text("Saving...")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
        }
    }
    
    // MARK: - Pre-Workout View
    
    private var preWorkoutView: some View {
        ZStack {
            WatchGradientBackground()
            
            VStack(spacing: 10) {
                Spacer()
                
                Image(systemName: "figure.run")
                    .font(.system(size: 36, weight: .light))
                    .foregroundColor(.white.opacity(0.8))
                
                Text("PulseTempo")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Ready to run")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
                
                Spacer()
                
                WatchStyledButton(
                    title: "Start",
                    icon: "play.fill",
                    tintColor: .green,
                    isProminent: true,
                    action: { workoutManager.requestWorkoutStart() }
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
        }
    }
    
    // MARK: - Waiting for Phone View
    
    private var waitingForPhoneView: some View {
        ZStack {
            WatchGradientBackground()
            
            VStack(spacing: 10) {
                Spacer()
                
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(.white)
                
                Text("Waiting...")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                HStack(spacing: 4) {
                    Image(systemName: "iphone")
                        .foregroundColor(.blue)
                    Text("Open iPhone")
                        .foregroundColor(.white.opacity(0.7))
                }
                .font(.system(size: 12, weight: .medium))
                
                Text("to start workout")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
                
                Spacer()
                
                WatchStyledButton(
                    title: "Cancel",
                    icon: "xmark",
                    tintColor: .red,
                    fillColor: Color.red.opacity(0.15),
                    action: { workoutManager.cancelWaiting() }
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
        }
    }
    
    // MARK: - Pending Phone Request View
    
    private var pendingPhoneRequestView: some View {
        ZStack {
            WatchGradientBackground()
            
            VStack(spacing: 10) {
                Spacer()
                
                HStack(spacing: 6) {
                    Image(systemName: "iphone")
                        .foregroundColor(.blue)
                    Image(systemName: "arrow.right")
                        .foregroundColor(.white.opacity(0.4))
                        .font(.system(size: 10))
                    Image(systemName: "applewatch")
                        .foregroundColor(.green)
                }
                .font(.system(size: 20))
                
                Text("Start Workout?")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                Text("iPhone is ready")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
                
                Spacer()
                
                VStack(spacing: 6) {
                    WatchStyledButton(
                        title: "Start",
                        icon: "play.fill",
                        tintColor: .green,
                        isProminent: true,
                        action: { workoutManager.acceptPhoneRequest() }
                    )
                    
                    WatchStyledButton(
                        title: "Cancel",
                        icon: "xmark",
                        tintColor: .red,
                        fillColor: Color.red.opacity(0.15),
                        action: { workoutManager.declinePhoneRequest() }
                    )
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
        }
    }
    
    // MARK: - Workout Tab View (Swipe Navigation)
    
    private var workoutTabView: some View {
        TabView {
            metricsView
            controlsView
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
    }
    
    // MARK: - Metrics View (Page 1)
    
    private var metricsView: some View {
        let zone = WatchHeartRateZone.zone(for: workoutManager.heartRate)
        
        return ZStack {
            WatchGradientBackground(accentColor: zone.color)
            
            VStack(spacing: 2) {
                // Paused indicator
                if workoutManager.syncState == .paused {
                    HStack(spacing: 4) {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 9))
                        Text("PAUSED")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1)
                    }
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color.orange.opacity(0.2))
                    )
                    .padding(.bottom, 2)
                }
                
                // Elapsed time
                Text(workoutManager.elapsedTimeString)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(workoutManager.syncState == .paused ? .orange : .white.opacity(0.7))
                
                // Heart icon with pulse
                Image(systemName: "heart.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.red)
                    .symbolEffect(.pulse, options: .repeating)
                    .padding(.top, 2)
                
                // Heart rate (large)
                Text("\(Int(workoutManager.heartRate))")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("BPM")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .offset(y: -4)
                
                // Heart rate zone badge
                Text(zone.name)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(zone.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(zone.color.opacity(0.2))
                    )
                
                // Cadence
                HStack(spacing: 4) {
                    Image(systemName: "figure.run")
                        .foregroundColor(.cyan)
                    Text("\(Int(workoutManager.cadence)) SPM")
                        .foregroundColor(.cyan)
                }
                .font(.system(size: 13, weight: .semibold))
                .padding(.top, 4)
                
                // BPM Lock indicator
                if connectivityManager.isBPMLocked {
                    HStack(spacing: 3) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 8))
                        if let value = connectivityManager.lockedBPMValue {
                            Text("Locked \(value)")
                        } else {
                            Text("Locked")
                        }
                    }
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.yellow)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.yellow.opacity(0.15))
                    )
                    .padding(.top, 2)
                }
                
                Spacer()
                
                // Swipe hint
                HStack {
                    Spacer()
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.3))
                }
                .padding(.trailing, 8)
                .padding(.bottom, 4)
            }
            .padding(.top, 8)
        }
    }
    
    // MARK: - Controls View (Page 2)
    
    private var controlsView: some View {
        ZStack {
            WatchGradientBackground()
            
            VStack(spacing: 8) {
                // Finish (prominent green)
                WatchStyledButton(
                    title: "Finish",
                    icon: "flag.checkered",
                    tintColor: .green,
                    isProminent: true,
                    action: { workoutManager.finishWorkout() }
                )
                
                // Pause / Resume
                if workoutManager.syncState == .paused {
                    WatchStyledButton(
                        title: "Resume",
                        icon: "play.fill",
                        tintColor: .green,
                        fillColor: Color.green.opacity(0.15),
                        action: { workoutManager.resumeWorkout() }
                    )
                } else {
                    WatchStyledButton(
                        title: "Pause",
                        icon: "pause.fill",
                        tintColor: .white,
                        action: { workoutManager.pauseWorkout() }
                    )
                }
                
                // BPM Lock
                WatchStyledButton(
                    title: bpmLockTitle,
                    icon: connectivityManager.isBPMLocked ? "lock.fill" : "lock.open",
                    tintColor: connectivityManager.isBPMLocked ? .yellow : .white,
                    fillColor: connectivityManager.isBPMLocked ? Color.yellow.opacity(0.15) : Color.white.opacity(0.10),
                    action: { connectivityManager.sendToggleBPMLockCommand() }
                )
                
                // Stop (red outline)
                WatchStyledButton(
                    title: "Stop",
                    icon: "xmark",
                    tintColor: .red,
                    fillColor: Color.red.opacity(0.12),
                    action: { workoutManager.showDiscardConfirmation() }
                )
            }
            .padding(.horizontal, 10)
        }
    }
    
    private var bpmLockTitle: String {
        if connectivityManager.isBPMLocked, let value = connectivityManager.lockedBPMValue {
            return "Unlock (\(value))"
        }
        return connectivityManager.isBPMLocked ? "Unlock" : "Lock BPM"
    }
    
    // MARK: - Discard Confirmation View
    
    private var discardConfirmationView: some View {
        ZStack {
            WatchGradientBackground(accentColor: .red)
            
            VStack(spacing: 10) {
                Spacer()
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(.red)
                
                Text("Discard Workout?")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                
                Text("This cannot be undone.")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
                    .multilineTextAlignment(.center)
                
                Spacer()
                
                VStack(spacing: 6) {
                    WatchStyledButton(
                        title: "Discard",
                        icon: "trash.fill",
                        tintColor: .red,
                        isProminent: true,
                        action: { workoutManager.discardWorkout() }
                    )
                    
                    WatchStyledButton(
                        title: "Cancel",
                        icon: "arrow.left",
                        tintColor: .white,
                        action: { workoutManager.cancelDiscard() }
                    )
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
        }
    }
    
    // MARK: - Summary View
    
    private var summaryView: some View {
        ZStack {
            WatchGradientBackground(accentColor: .green)
            
            ScrollView {
                VStack(spacing: 8) {
                    // Header
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 28, weight: .thin))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.top, 8)
                    
                    Text("Complete")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    // Total time
                    Text(workoutManager.elapsedTimeString)
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.vertical, 2)
                    
                    // Stats in glass cards
                    HStack(spacing: 6) {
                        WatchStatCard(
                            icon: "heart.fill",
                            iconColor: .red,
                            value: "\(workoutManager.averageHeartRate)",
                            unit: "BPM"
                        )
                        
                        WatchStatCard(
                            icon: "figure.run",
                            iconColor: .cyan,
                            value: "\(workoutManager.averageCadence)",
                            unit: "SPM"
                        )
                    }
                    .padding(.horizontal, 8)
                    
                    // Home button
                    WatchStyledButton(
                        title: "Home",
                        icon: "house.fill",
                        tintColor: .green,
                        isProminent: true,
                        action: { workoutManager.dismissSummary() }
                    )
                    .padding(.horizontal, 12)
                    .padding(.top, 6)
                    .padding(.bottom, 12)
                }
            }
        }
    }
}

// MARK: - Watch Stat Card

struct WatchStatCard: View {
    let icon: String
    var iconColor: Color = .white
    let value: String
    let unit: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(iconColor)
            
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text(unit)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .watchGlassCard()
    }
}

// MARK: - Preview

#Preview {
    ContentView(
        workoutManager: WorkoutManager(),
        connectivityManager: PhoneConnectivityManager()
    )
}
