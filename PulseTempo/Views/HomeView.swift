//
//  HomeView.swift
//  inSync
//
//  Created by Zavier Rodrigues on 11/17/25.
//

import SwiftUI

/// Home screen dashboard - central hub before starting workouts
struct HomeView: View {
    
    // MARK: - Properties
    
    @ObservedObject var viewModel: HomeViewModel
    @ObservedObject private var connectivityManager = WatchConnectivityManager.shared
    
    /// Navigation state
    @State private var showingActiveRun = false
    
    /// Workout tracks state
    @State private var workoutTracks: [Track] = []
    @State private var isLoadingTracks = false
    @State private var trackLoadError: String?
    
    /// Selected workout mode (Heart Rate vs Cadence)
    @State private var selectedRunMode: RunMode = .steadyTempo
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                GradientBackground()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Logo at top
                        InSyncLogo(size: .medium)
                            .padding(.top, 8)
                        
                        // Header
                        headerSection
                        
                        // Quick Start Area
                        quickStartSection
                        
                        // Selected Playlists Summary
                        playlistSummarySection
                        
                        // Last Workout (if available)
                        if let lastWorkout = viewModel.lastWorkout {
                            lastWorkoutSection(lastWorkout)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
            .navigationBarHidden(true)
            .fullScreenCover(isPresented: $showingActiveRun) {
                ActiveRunView(tracks: workoutTracks, runMode: selectedRunMode)
            }
            .onAppear {
                viewModel.refreshPlaylists()
                viewModel.refreshRunHistory()
            }
            .overlay {
                // Waiting for Watch overlay
                if connectivityManager.isWaitingForWatch {
                    waitingForWatchOverlay
                }
            }
        }
    }
    
    // MARK: - Waiting for Watch Overlay
    
    private var waitingForWatchOverlay: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                
                Text("Waiting for Watch...")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                
                HStack(spacing: 8) {
                    Image(systemName: "applewatch")
                        .foregroundColor(.green)
                    Text("Open Apple Watch to start")
                        .font(.bebasNeueSubheadline)
                }
                .foregroundColor(.white.opacity(0.8))
                
                Button(action: {
                    connectivityManager.cancelWaitingForWatch()
                }) {
                    Text("Cancel")
                        .font(.bebasNeueTitle)
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(Color.red.opacity(0.8))
                        .cornerRadius(10)
                }
                .padding(.top, 8)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.7))
            )
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Ready to Work Out")
                    .font(.bebasNeueMedium)
                    .foregroundColor(.white)
                
                if viewModel.totalTrackCount > 0 {
                    Text("\(viewModel.totalTrackCount) songs ready")
                        .font(.bebasNeueSubheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            Spacer()
        }
        .padding(.top, 8)
    }
    
    // MARK: - Quick Start Section
    
    private var quickStartSection: some View {
        VStack(spacing: 16) {
            // Workout Mode Selector
            workoutModeSelector
            
            // Main Start Workout Button
            Button(action: startWorkout) {
                HStack {
                    if isLoadingTracks {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.2)
                    } else {
                        Image(systemName: "figure.run")
                            .font(.system(size: 24, weight: .semibold))
                    }
                    
                    Text(isLoadingTracks ? "Loading..." : "Start Workout")
                        .font(.system(size: 20, weight: .bold))
                    
                    Spacer()
                    
                    if !isLoadingTracks {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 28))
                    }
                }
                .foregroundColor(.white)
                .padding(20)
                .background(
                    LinearGradient(
                        colors: selectedRunMode == .cadenceMatching
                            ? [Color.cyan, Color.teal]
                            : [Color.pink, Color.red],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
                .shadow(color: .red.opacity(0.3), radius: 12, x: 0, y: 6)
            }
            .disabled(isLoadingTracks)
            
            // Workout Info
            if !viewModel.selectedPlaylists.isEmpty {
                HStack(spacing: 20) {
                    InfoPill(
                        icon: "music.note.list",
                        text: "\(viewModel.selectedPlaylists.count) \(viewModel.selectedPlaylists.count == 1 ? "playlist" : "playlists")",
                        color: .purple
                    )
                    
                    // Only show song count if available
                    if viewModel.totalTrackCount > 0 {
                        InfoPill(
                            icon: "music.note",
                            text: "\(viewModel.totalTrackCount) songs",
                            color: .red
                        )
                    }
                }
            }
        }
        .padding(20)
        .glassCardStyle()
    }
    
    // MARK: - Workout Mode Selector
    
    /// Toggle between Heart Rate and Cadence matching modes
    private var workoutModeSelector: some View {
        VStack(spacing: 8) {
            Text("Match Music To")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
            
            HStack(spacing: 12) {
                // Heart Rate Mode Button
                WorkoutModeButton(
                    mode: .steadyTempo,
                    isSelected: selectedRunMode == .steadyTempo,
                    action: { selectedRunMode = .steadyTempo }
                )
                
                // Cadence Mode Button
                WorkoutModeButton(
                    mode: .cadenceMatching,
                    isSelected: selectedRunMode == .cadenceMatching,
                    action: { selectedRunMode = .cadenceMatching }
                )
            }
        }
        .padding(.bottom, 8)
    }
    
    // MARK: - Playlist Summary Section
    
    private var playlistSummarySection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Your Playlists")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.2)
                    .padding(.vertical, 20)
            } else if viewModel.selectedPlaylists.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 24))
                        .foregroundColor(.gray.opacity(0.5))
                    
                    Text("No playlists selected — go to Playlists tab")
                        .font(.bebasNeueSubheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.vertical, 16)
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.selectedPlaylists.prefix(3)) { playlist in
                        PlaylistOverviewCard(playlist: playlist) { }
                    }
                    
                    if viewModel.selectedPlaylists.count > 3 {
                        Text("+\(viewModel.selectedPlaylists.count - 3) more")
                            .font(.bebasNeueCaption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
        }
        .padding(20)
        .glassCardStyle()
    }
    
    // MARK: - Last Workout Section
    
    private func lastWorkoutSection(_ workout: WorkoutSummary) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text("Last Workout")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.formattedDate)
                        .font(.bebasNeueSubheadline)
                        .foregroundColor(.white.opacity(0.7))
                    
                    HStack(spacing: 12) {
                        Label("\(workout.formattedDuration)", systemImage: "clock")
                        Label("\(workout.averageBPM) BPM", systemImage: "heart.fill")
                        if workout.averageCadence > 0 {
                            Label("\(workout.averageCadence) SPM", systemImage: "figure.run")
                        }
                    }
                    .font(.bebasNeueCaption)
                    .foregroundColor(.white)
                }
                
                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.red.opacity(0.1))
            )
        }
        .padding(20)
        .glassCardStyle()
    }
    
    // MARK: - Helper Methods
    
    /// Fetch tracks from selected playlists and start workout
    private func startWorkout() {
        isLoadingTracks = true
        trackLoadError = nil
        
        viewModel.fetchTracksForWorkout { result in
            isLoadingTracks = false
            
            switch result {
            case .success(let tracks):
                workoutTracks = tracks
                
                // Check if watch already requested workout (watch-first flow)
                if connectivityManager.hasPendingWorkoutRequest {
                    print("✅ [iOS] Watch already requested - confirming and starting immediately")
                    connectivityManager.clearPendingWorkoutRequest()
                    connectivityManager.sendWorkoutStartedConfirmation()
                    showingActiveRun = true
                    return
                }
                
                // Phone-first flow: Send workout request to watch and wait for confirmation
                connectivityManager.requestWorkoutFromPhone()
                
                // Set up callback for when watch confirms - only then navigate to ActiveRunView
                connectivityManager.onWatchWorkoutStarted = {
                    connectivityManager.isWaitingForWatch = false
                    showingActiveRun = true
                }
                
                // If watch workout is already active, start immediately (no need to wait)
                if connectivityManager.isWatchWorkoutActive {
                    connectivityManager.isWaitingForWatch = false
                    showingActiveRun = true
                }
                // Otherwise, isWaitingForWatch will show the overlay until watch confirms
                
            case .failure(let error):
                trackLoadError = error.localizedDescription
                // Show error alert
                print("❌ Failed to load tracks: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Info Pill Component

/// Small pill-shaped info display
struct InfoPill: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.bebasNeueCaption)
            
            Text(text)
                .font(.system(size: 14, weight: .medium))
        }
        .foregroundColor(color)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(color.opacity(0.15))
        )
    }
}

// MARK: - Workout Mode Button Component

/// Button for selecting workout mode (Heart Rate vs Cadence)
struct WorkoutModeButton: View {
    let mode: RunMode
    let isSelected: Bool
    let action: () -> Void
    
    private var modeColor: Color {
        switch mode {
        case .steadyTempo:
            return .red
        case .cadenceMatching:
            return .cyan
        default:
            return .blue
        }
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: mode.icon)
                    .font(.bebasNeueTitle)
                
                Text(mode.displayName)
                    .font(.system(size: 13, weight: .semibold))
                
                Text(mode.description)
                    .font(.system(size: 10))
                    .foregroundColor(isSelected ? modeColor.opacity(0.8) : .white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .foregroundColor(isSelected ? modeColor : .white.opacity(0.7))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? modeColor.opacity(0.15) : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? modeColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#if DEBUG
struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView(viewModel: HomeViewModel())
    }
}
#endif
