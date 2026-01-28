//
//  HomeView.swift
//  PulseTempo
//
//  Created by Zavier Rodrigues on 11/17/25.
//

import SwiftUI

/// Home screen dashboard - central hub before starting workouts
/// Features Quick Start area and Playlist Management
struct HomeView: View {
    
    // MARK: - Properties
    
    @StateObject private var viewModel = HomeViewModel()
    @ObservedObject private var connectivityManager = WatchConnectivityManager.shared
    
    /// Navigation state
    @State private var showingActiveRun = false
    @State private var showingPlaylistSelection = false
    @State private var selectedPlaylistForViewing: MusicPlaylist?
    
    /// Workout tracks state
    @State private var workoutTracks: [Track] = []
    @State private var isLoadingTracks = false
    @State private var trackLoadError: String?
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.95, green: 0.97, blue: 1.0),
                        Color(red: 0.90, green: 0.95, blue: 1.0)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        headerSection
                        
                        // Quick Start Area
                        quickStartSection
                        
                        // Playlist Management
                        playlistManagementSection
                        
                        // Last Workout (if available)
                        if let lastWorkout = viewModel.lastWorkout {
                            lastWorkoutSection(lastWorkout)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("PulseTempo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // TODO: Open settings
                    }) {
                        Image(systemName: "gear")
                            .foregroundColor(.black)
                    }
                }
            }
            .fullScreenCover(isPresented: $showingActiveRun) {
                ActiveRunView(tracks: workoutTracks)
            }
            .sheet(isPresented: $showingPlaylistSelection) {
                PlaylistSelectionView { tracks in
                    // Handle playlist selection
                    print("✅ Selected \(tracks.count) tracks from playlists")
                    showingPlaylistSelection = false
                    viewModel.refreshPlaylists()
                }
            }
            .sheet(item: $selectedPlaylistForViewing) { playlist in
                PlaylistSongsView(
                    playlist: playlist,
                    onDismiss: {
                        selectedPlaylistForViewing = nil
                    }
                )
            }
            .onAppear {
                viewModel.refreshPlaylists()
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
                        .font(.subheadline)
                }
                .foregroundColor(.white.opacity(0.8))
                
                Button(action: {
                    connectivityManager.cancelWaitingForWatch()
                }) {
                    Text("Cancel")
                        .font(.headline)
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
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                
                if viewModel.totalTrackCount > 0 {
                    Text("\(viewModel.totalTrackCount) songs ready")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
        }
        .padding(.top, 8)
    }
    
    // MARK: - Quick Start Section
    
    private var quickStartSection: some View {
        VStack(spacing: 16) {
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
                        colors: [Color.blue, Color.purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
                .shadow(color: .blue.opacity(0.3), radius: 12, x: 0, y: 6)
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
                            color: .blue
                        )
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.8))
                .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
        )
    }
    
    // MARK: - Playlist Management Section
    
    private var playlistManagementSection: some View {
        VStack(spacing: 16) {
            // Section header
            HStack {
                Text("Your Playlists")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: {
                    showingPlaylistSelection = true
                }) {
                    HStack(spacing: 4) {
                        Text("Manage")
                            .font(.system(size: 15, weight: .semibold))
                        Image(systemName: "pencil")
                            .font(.system(size: 13))
                    }
                    .foregroundColor(.blue)
                }
            }
            
            // Playlist cards
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.2)
                    .padding(.vertical, 40)
            } else if viewModel.selectedPlaylists.isEmpty {
                emptyPlaylistsView
            } else {
                VStack(spacing: 12) {
                    ForEach(viewModel.selectedPlaylists) { playlist in
                        PlaylistOverviewCard(playlist: playlist) {
                            selectedPlaylistForViewing = playlist
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.8))
                .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
        )
    }
    
    // MARK: - Empty Playlists View
    
    private var emptyPlaylistsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "music.note.list")
                .font(.system(size: 40))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No Playlists Selected")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Add playlists to get started")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button(action: {
                showingPlaylistSelection = true
            }) {
                Text("Add Playlists")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.top, 8)
        }
        .padding(.vertical, 30)
    }
    
    // MARK: - Last Workout Section
    
    private func lastWorkoutSection(_ workout: WorkoutSummary) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text("Last Workout")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.formattedDate)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        Label("\(workout.formattedDuration)", systemImage: "clock")
                        Label("\(workout.averageBPM) BPM", systemImage: "heart.fill")
                        Label("\(workout.songsPlayed) songs", systemImage: "music.note")
                    }
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue.opacity(0.1))
            )
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.8))
                .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
        )
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
                .font(.system(size: 14))
            
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

// MARK: - Preview

#if DEBUG
struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
#endif
