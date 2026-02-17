//
//  ActiveRunView.swift
//  inSync
//
//  Created by Zavier Rodrigues on 2/3/26.
//

import SwiftUI

/// Main view displayed during an active workout session
/// Shows heart rate, current track, playback controls, and session stats
@MainActor
struct ActiveRunView: View {
    
    // MARK: - Properties
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var runSessionVM: RunSessionViewModel
    @State private var showingQuitConfirmation = false
    @State private var showingControlsSheet = false
    @State private var isAnimatingChevron = false
    @State private var showingSelectedPlaylists = false
    @State private var showingAddSongsPicker = false
    @State private var selectedPlaylistForAdd: MusicPlaylist?
    @State private var controlsSheetDetent: PresentationDetent = .large
    @State private var pendingSheet: PendingSheet?

    private let selectedPlaylists: [MusicPlaylist]

    private enum PendingSheet {
        case playlists
        case addSongs(MusicPlaylist)
    }
    
    // MARK: - Initialization
    
    init(tracks: [Track], runMode: RunMode, selectedPlaylists: [MusicPlaylist] = []) {
        _runSessionVM = StateObject(wrappedValue: RunSessionViewModel(tracks: tracks, runMode: runMode))
        self.selectedPlaylists = selectedPlaylists
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Background gradient based on heart rate zone
            backgroundGradient
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top bar with close button and timer
                topBar
                
                Spacer()
                
                // Heart rate display
                heartRateSection
                
                // Cadence display (if available from watch)
                if runSessionVM.currentCadence > 0 {
                    cadenceSection
                }
                
                Spacer()
                
                // Current track info
                trackInfoSection
                
                // Playback controls
                controlsSection
                    .padding(.bottom, 20)
                
                // Swipe up indicator
                VStack(spacing: 4) {
                    Image(systemName: "chevron.compact.up")
                        .font(.custom("BebasNeue-Regular", size: 24))
                        .foregroundColor(.white.opacity(0.7))
                        .offset(y: isAnimatingChevron ? -5 : 0)
                        .animation(
                            Animation.easeInOut(duration: 1.0)
                                .repeatForever(autoreverses: true),
                            value: isAnimatingChevron
                        )
                    
                    Text("SWIPE UP FOR CONTROLS")
                        .font(.custom("BebasNeue-Regular", size: 14))
                        .foregroundColor(.white.opacity(0.5))
                        .tracking(1)
                }
                .padding(.bottom, 20)
                .onAppear {
                    isAnimatingChevron = true
                }
            }
        }
        .contentShape(Rectangle()) // Make entire area tappable/swipable
        .gesture(
            DragGesture(minimumDistance: 20, coordinateSpace: .local)
                .onEnded { value in
                    if value.translation.height < 0 {
                        // Swipe up
                        showingControlsSheet = true
                    }
                }
        )
        .onAppear {
            runSessionVM.startRun()
        }
        .onChange(of: runSessionVM.shouldDismissEntireView) { _, shouldDismiss in
            if shouldDismiss {
                dismiss()
            }
        }
        .sheet(isPresented: Binding(
            get: { runSessionVM.showingSummary },
            set: { runSessionVM.showingSummary = $0 }
        )) {
            WorkoutSummaryView(
                elapsedTime: runSessionVM.elapsedTime,
                averageHeartRate: runSessionVM.averageHeartRate,
                maxHeartRate: runSessionVM.maxHeartRate,
                averageCadence: runSessionVM.averageCadence,
                tracksPlayed: runSessionVM.tracksPlayed,
                onDismiss: {
                    runSessionVM.showingSummary = false
                    dismiss()
                }
            )
            .interactiveDismissDisabled()
        }
        // Workout Controls Sheet
        .sheet(isPresented: $showingControlsSheet) {
            ZStack {
                // Background matching the app
                GradientBackground()
                
                VStack(spacing: 20) {
                    // Handle indicator
                    Capsule()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 36, height: 4)
                        .padding(.top, 12)
                    
                    // Now Playing controls
                    VStack(spacing: 14) {
                        // Track title/artist (if available)
                        if let track = runSessionVM.currentTrack {
                            VStack(spacing: 4) {
                                Text(track.title)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Text(track.artist)
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.5))
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        
                        // Progress bar (shows progress if duration available)
                        if let track = runSessionVM.currentTrack, track.durationSeconds > 0 {
                            VStack(spacing: 6) {
                                ProgressView(value: runSessionVM.currentPlaybackTime, total: Double(track.durationSeconds))
                                    .progressViewStyle(LinearProgressViewStyle())
                                    .tint(.white.opacity(0.6))
                                    .frame(maxWidth: .infinity)
                                HStack {
                                    Text(formatTime(runSessionVM.currentPlaybackTime))
                                        .font(.caption2)
                                        .foregroundColor(.white.opacity(0.4))
                                    Spacer()
                                    let remaining = max(0, Double(track.durationSeconds) - runSessionVM.currentPlaybackTime)
                                    Text("-\(formatTime(remaining))")
                                        .font(.caption2)
                                        .foregroundColor(.white.opacity(0.4))
                                }
                            }
                        } else {
                            ProgressView()
                                .progressViewStyle(LinearProgressViewStyle())
                                .tint(.white.opacity(0.4))
                                .frame(maxWidth: .infinity)
                        }
                        
                        // Transport controls (back, play/pause, next)
                        HStack(spacing: 44) {
                            Button(action: { runSessionVM.skipToPreviousTrack() }) {
                                Image(systemName: "backward.fill")
                                    .font(.title3)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            
                            Button(action: { runSessionVM.toggleMusicPlayPause() }) {
                                Image(systemName: runSessionVM.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.white)
                            }
                            
                            Button(action: { runSessionVM.skipToNextTrack() }) {
                                Image(systemName: "forward.fill")
                                    .font(.title3)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                        .padding(.top, 2)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    )

                    // Queue + playlist actions
                    playlistQueueSection
                    
                    // Workout action buttons
                    HStack(spacing: 12) {
                        // Quit
                        Button(action: {
                            showingControlsSheet = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                showingQuitConfirmation = true
                            }
                        }) {
                            VStack(spacing: 6) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.red.opacity(0.9))
                                Text("Quit")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 64)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.white.opacity(0.06))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Pause / Resume Workout (workout timer only - music unaffected)
                        Button(action: {
                            runSessionVM.toggleWorkoutPause()
                            showingControlsSheet = false
                        }) {
                            VStack(spacing: 6) {
                                Image(systemName: runSessionVM.isWorkoutPaused ? "figure.run" : "pause.fill")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.white)
                                Text(runSessionVM.isWorkoutPaused ? "Resume" : "Pause")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 64)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.white.opacity(runSessionVM.isWorkoutPaused ? 0.12 : 0.06))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // BPM Lock (freeze target HR/cadence for queue)
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                runSessionVM.toggleBPMLock()
                            }
                        }) {
                            VStack(spacing: 6) {
                                Image(systemName: runSessionVM.isBPMLocked ? "lock.fill" : "lock.open")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(runSessionVM.isBPMLocked ? .yellow : .white)
                                Text(runSessionVM.isBPMLocked ? "Unlock" : "Lock")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 64)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(runSessionVM.isBPMLocked ? Color.yellow.opacity(0.12) : Color.white.opacity(0.06))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(Color.white.opacity(runSessionVM.isBPMLocked ? 0.2 : 0.1), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Finish
                        Button(action: {
                            showingControlsSheet = false
                            runSessionVM.finishRun()
                        }) {
                            VStack(spacing: 6) {
                                Image(systemName: "flag.checkered")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.white)
                                Text("Finish")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 64)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.white.opacity(0.06))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
            }
            .presentationDetents([.medium, .large], selection: $controlsSheetDetent)
            .presentationDragIndicator(.hidden)
        }
        .onChange(of: showingControlsSheet) { _, isPresented in
            if isPresented {
                controlsSheetDetent = .large
            } else {
                presentPendingSheetIfNeeded()
            }
        }
        .sheet(isPresented: $showingSelectedPlaylists) {
            SelectedPlaylistsSheet(playlists: selectedPlaylists, onSongsAdded: { addedTracks in
                runSessionVM.addTracksToWorkout(addedTracks)
            })
        }
        .sheet(item: $selectedPlaylistForAdd) { playlist in
            MusicSearchView(playlistId: playlist.id) { addedTracks in
                runSessionVM.addTracksToWorkout(addedTracks)
                persistPendingTracks(addedTracks, playlistId: playlist.id)
            }
        }
        .confirmationDialog(
            "Add songs to which playlist?",
            isPresented: $showingAddSongsPicker,
            titleVisibility: .visible
        ) {
            ForEach(selectedPlaylists) { playlist in
                Button(playlist.name) {
                    queueSheet(.addSongs(playlist))
                }
            }
        }
        .alert("Quit Workout?", isPresented: $showingQuitConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Quit", role: .destructive) {
                runSessionVM.discardRun()
                dismiss()
            }
        } message: {
            Text("This will discard your workout. Are you sure?")
        }
    }
    
    // MARK: - Background
    
    private var backgroundGradient: some View {
        let zone = HeartRateZone.zone(for: runSessionVM.currentHeartRate)
        return LinearGradient(
            gradient: Gradient(colors: [
                zone.color.opacity(0.8),
                zone.color.opacity(0.4),
                Color.black
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        HStack {
            // Run mode indicator (restored)
            VStack(spacing: 2) {
                Text("MODE")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
                Text(runSessionVM.runMode.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            // Elapsed time
            VStack(spacing: 2) {
                Text("DURATION")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
                Text(formatTime(runSessionVM.elapsedTime))
                    .font(.title2.monospacedDigit())
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            // Empty view for symmetry
            VStack(spacing: 2) {
                Text("MODE")
                    .font(.caption2)
                    .foregroundColor(.clear)
                Text(runSessionVM.runMode.displayName)
                    .font(.caption)
                    .foregroundColor(.clear)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
    
    // MARK: - Heart Rate Section
    
    private var heartRateSection: some View {
        VStack(spacing: 8) {
            // Heart icon with pulse animation
            Image(systemName: "heart.fill")
                .font(.system(size: 40))
                .foregroundColor(.red)
                .symbolEffect(.pulse, options: .repeating)
            
            // Current heart rate
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(runSessionVM.currentHeartRate)")
                    .font(.system(size: 96, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("BPM")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            // Heart rate zone
            let zone = HeartRateZone.zone(for: runSessionVM.currentHeartRate)
            Text(zone.name)
                .font(.headline)
                .foregroundColor(zone.color)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(zone.color.opacity(0.2))
                .clipShape(Capsule())
        }
    }
    
    // MARK: - Cadence Section
    
    private var cadenceSection: some View {
        HStack(spacing: 6) {
            Image(systemName: "figure.run")
                .foregroundColor(.cyan)
            Text("\(runSessionVM.currentCadence) SPM")
                .font(.headline)
                .foregroundColor(.cyan)
        }
        .padding(.top, 8)
    }
    
    // MARK: - Track Info Section
    
    private var trackInfoSection: some View {
        VStack(spacing: 12) {
            // Album artwork placeholder
            if let track = runSessionVM.currentTrack {
                AsyncImage(url: track.artworkURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.largeTitle)
                                .foregroundColor(.white.opacity(0.3))
                        )
                }
                .frame(width: 200, height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(radius: 20)
                
                // Track title and artist
                VStack(spacing: 4) {
                    Text(track.title)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(track.artist)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                    
                    // BPM badge
                    if let bpm = track.bpm {
                        Text("\(Int(bpm)) BPM")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                            .padding(.top, 2)
                    }
                }
                .padding(.horizontal, 40)
            } else {
                // No track playing
                VStack(spacing: 8) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 60))
                        .foregroundColor(.white.opacity(0.3))
                    Text("No track playing")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.5))
                }
            }
        }
        .padding(.bottom, 30)
    }
    
    // MARK: - Controls Section
    
    private var controlsSection: some View {
        HStack(spacing: 40) {
            // Previous track
            Button(action: {
                runSessionVM.skipToPreviousTrack()
            }) {
                Image(systemName: "backward.fill")
                    .font(.title)
                    .foregroundColor(.white)
            }
            
            // Play/Pause (music only - workout timer unaffected)
            Button(action: {
                runSessionVM.toggleMusicPlayPause()
            }) {
                Image(systemName: runSessionVM.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 72))
                    .foregroundColor(.white)
            }
            
            // Next track
            Button(action: {
                runSessionVM.skipToNextTrack()
            }) {
                Image(systemName: "forward.fill")
                    .font(.title)
                    .foregroundColor(.white)
            }
        }
        .overlay(alignment: .trailing) {
            // BPM Lock button — positioned to the right of controls
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    runSessionVM.toggleBPMLock()
                }
            }) {
                Image(systemName: runSessionVM.isBPMLocked ? "lock.fill" : "lock.open")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(runSessionVM.isBPMLocked ? .yellow : .white.opacity(0.6))
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(runSessionVM.isBPMLocked ? Color.yellow.opacity(0.15) : Color.white.opacity(0.08))
                    )
                    .scaleEffect(runSessionVM.isBPMLocked ? 1.1 : 1.0)
            }
            .offset(x: 56)
        }
    }

    // MARK: - Playlist + Queue Section

    private var playlistQueueSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Up Next")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                
                // BPM Lock indicator
                if runSessionVM.isBPMLocked {
                    HStack(spacing: 3) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9, weight: .bold))
                        let lockedValue = runSessionVM.runMode == .cadenceMatching
                            ? "\(runSessionVM.lockedCadence ?? 0) SPM"
                            : "\(runSessionVM.lockedHeartRate ?? 0) BPM"
                        Text("Locked at \(lockedValue)")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(.yellow)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color.yellow.opacity(0.15))
                    )
                    .transition(.opacity.combined(with: .scale))
                }
                
                Spacer()
                Button(action: { queueSheet(.playlists) }) {
                    HStack(spacing: 4) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Playlists")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.15))
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }

            if let nextTrack = runSessionVM.queuedNextTrack {
                VStack(spacing: 2) {
                    Text(nextTrack.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(nextTrack.artist)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("Queue adapting to your pace...")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button(action: {
                guard !selectedPlaylists.isEmpty else { return }
                if selectedPlaylists.count == 1 {
                    queueSheet(.addSongs(selectedPlaylists[0]))
                } else {
                    showingAddSongsPicker = true
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                    Text("Add Songs")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(selectedPlaylists.isEmpty ? Color.white.opacity(0.08) : Color.white.opacity(0.2))
                )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(selectedPlaylists.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
    }
    
    // MARK: - Helpers
    
    private func formatTime(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Sheet Routing

    private func queueSheet(_ sheet: PendingSheet) {
        if showingControlsSheet {
            pendingSheet = sheet
            showingControlsSheet = false
        } else {
            pendingSheet = sheet
            presentPendingSheetIfNeeded()
        }
    }

    private func presentPendingSheetIfNeeded() {
        guard let pending = pendingSheet else { return }
        pendingSheet = nil
        DispatchQueue.main.async {
            switch pending {
            case .playlists:
                showingSelectedPlaylists = true
            case .addSongs(let playlist):
                selectedPlaylistForAdd = playlist
            }
        }
    }

    // MARK: - Pending Track Persistence

    private func pendingTracksKey(for playlistId: String) -> String {
        "pendingTracks_\(playlistId)"
    }

    private func loadPendingTracks(for playlistId: String) -> [Track] {
        guard let encoded = UserDefaults.standard.array(forKey: pendingTracksKey(for: playlistId)) as? [[String: String]] else {
            return []
        }
        let bpmCache = UserDefaults.standard.dictionary(forKey: "com.pulsetempo.bpmCache") as? [String: Int] ?? [:]
        return encoded.compactMap { dict in
            guard let id = dict["id"], let title = dict["title"], let artist = dict["artist"],
                  let durationStr = dict["duration"], let duration = Int(durationStr) else { return nil }
            let artworkURL = dict["artworkURL"].flatMap { $0.isEmpty ? nil : URL(string: $0) }
            let bpm = bpmCache[id] ?? bpmCache["\(title.lowercased())|\(artist.lowercased())"]
            return Track(id: id, title: title, artist: artist, durationSeconds: duration, bpm: bpm, artworkURL: artworkURL)
        }
    }

    private func savePendingTracks(_ pending: [Track], playlistId: String) {
        let encoded = pending.map {
            [
                "id": $0.id,
                "title": $0.title,
                "artist": $0.artist,
                "duration": String($0.durationSeconds),
                "artworkURL": $0.artworkURL?.absoluteString ?? ""
            ]
        }
        UserDefaults.standard.set(encoded, forKey: pendingTracksKey(for: playlistId))
    }

    private func persistPendingTracks(_ addedTracks: [Track], playlistId: String) {
        guard !addedTracks.isEmpty else { return }
        var pending = loadPendingTracks(for: playlistId)
        let existingIds = Set(pending.map { $0.id })
        let existingTitles = Set(pending.map { "\($0.title.lowercased())|\($0.artist.lowercased())" })
        for track in addedTracks {
            let titleKey = "\(track.title.lowercased())|\(track.artist.lowercased())"
            if existingIds.contains(track.id) || existingTitles.contains(titleKey) {
                continue
            }
            pending.append(track)
        }
        savePendingTracks(pending, playlistId: playlistId)
    }
}

// MARK: - Workout Summary View

struct WorkoutSummaryView: View {
    let elapsedTime: TimeInterval
    let averageHeartRate: Int
    let maxHeartRate: Int
    let averageCadence: Int
    let tracksPlayed: [Track]
    let onDismiss: () -> Void
    
    /// Convenience initializer for displaying a historical WorkoutSummary
    init(workout: WorkoutSummary, onDismiss: @escaping () -> Void) {
        self.elapsedTime = TimeInterval(workout.durationMinutes * 60)
        self.averageHeartRate = workout.averageBPM
        self.maxHeartRate = 0
        self.averageCadence = workout.averageCadence
        self.tracksPlayed = []
        self.onDismiss = onDismiss
    }
    
    /// Primary initializer used after completing a live workout
    init(
        elapsedTime: TimeInterval,
        averageHeartRate: Int,
        maxHeartRate: Int,
        averageCadence: Int,
        tracksPlayed: [Track],
        onDismiss: @escaping () -> Void
    ) {
        self.elapsedTime = elapsedTime
        self.averageHeartRate = averageHeartRate
        self.maxHeartRate = maxHeartRate
        self.averageCadence = averageCadence
        self.tracksPlayed = tracksPlayed
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        ZStack {
            // Background matching the app
            GradientBackground()
            
            ScrollView {
                VStack(spacing: 28) {
                    // Header
                    VStack(spacing: 10) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 48, weight: .thin))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text("Workout Complete")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text(formatTime(elapsedTime))
                            .font(.system(size: 40, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundColor(.white)
                    }
                    .padding(.top, 40)
                    
                    // Stats grid
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        StatCard(title: "Avg Heart Rate", value: "\(averageHeartRate)", unit: "BPM", icon: "heart.fill")
                        if maxHeartRate > 0 {
                            StatCard(title: "Max Heart Rate", value: "\(maxHeartRate)", unit: "BPM", icon: "heart.fill")
                        }
                        StatCard(title: "Avg Cadence", value: "\(averageCadence)", unit: "SPM", icon: "figure.run")
                        if !tracksPlayed.isEmpty {
                            StatCard(title: "Tracks Played", value: "\(tracksPlayed.count)", unit: nil, icon: "music.note.list")
                        }
                    }
                    .padding(.horizontal, 16)
                    
                    // Tracks played section
                    if !tracksPlayed.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("TRACKS")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.4))
                                .tracking(1)
                                .padding(.horizontal, 20)
                            
                            VStack(spacing: 0) {
                                ForEach(Array(tracksPlayed.prefix(10).enumerated()), id: \.element.id) { index, track in
                                    HStack(spacing: 12) {
                                        AsyncImage(url: track.artworkURL) { image in
                                            image.resizable()
                                                .aspectRatio(contentMode: .fill)
                                        } placeholder: {
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(Color.white.opacity(0.08))
                                                .overlay(
                                                    Image(systemName: "music.note")
                                                        .font(.caption)
                                                        .foregroundColor(.white.opacity(0.3))
                                                )
                                        }
                                        .frame(width: 40, height: 40)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(track.title)
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(.white)
                                                .lineLimit(1)
                                            Text(track.artist)
                                                .font(.system(size: 12))
                                                .foregroundColor(.white.opacity(0.4))
                                                .lineLimit(1)
                                        }
                                        
                                        Spacer()
                                        
                                        if let bpm = track.bpm {
                                            Text("\(Int(bpm))")
                                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                                .foregroundColor(.white.opacity(0.3))
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    
                                    if index < min(tracksPlayed.count, 10) - 1 {
                                        Divider()
                                            .background(Color.white.opacity(0.06))
                                            .padding(.leading, 68)
                                    }
                                }
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.white.opacity(0.06))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                    )
                            )
                            .padding(.horizontal, 16)
                        }
                    }
                    
                    // Done button
                    Button(action: { onDismiss() }) {
                        Text("Done")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.white.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                                    )
                            )
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
            }
        }
    }
    
    private func formatTime(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    var unit: String? = nil
    let icon: String
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.4))
            
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                if let unit = unit {
                    Text(unit)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.35))
                }
            }
            
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

// MARK: - Preview

#if DEBUG
struct ActiveRunView_Previews: PreviewProvider {
    static var previews: some View {
        ActiveRunView(tracks: [], runMode: .steadyTempo)
    }
}
#endif
