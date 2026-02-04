//
//  ActiveRunView.swift
//  PulseTempo
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
    
    // MARK: - Initialization
    
    init(tracks: [Track], runMode: RunMode) {
        _runSessionVM = StateObject(wrappedValue: RunSessionViewModel(tracks: tracks, runMode: runMode))
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
                    .padding(.bottom, 40)
            }
        }
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
            // Close button
            Button(action: {
                runSessionVM.finishRun()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.white.opacity(0.7))
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
            
            // Run mode indicator
            VStack(spacing: 2) {
                Text("MODE")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
                Text(runSessionVM.runMode.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
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
            
            // Play/Pause
            Button(action: {
                runSessionVM.togglePlayPause()
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
    }
    
    // MARK: - Helpers
    
    private func formatTime(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
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
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        
                        Text("Workout Complete!")
                            .font(.title)
                            .fontWeight(.bold)
                    }
                    .padding(.top, 20)
                    
                    // Stats grid
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        StatCard(title: "Duration", value: formatTime(elapsedTime), icon: "clock.fill", color: .blue)
                        StatCard(title: "Avg HR", value: "\(averageHeartRate)", icon: "heart.fill", color: .red)
                        StatCard(title: "Max HR", value: "\(maxHeartRate)", icon: "heart.fill", color: .orange)
                        StatCard(title: "Avg Cadence", value: "\(averageCadence)", icon: "figure.run", color: .cyan)
                        StatCard(title: "Tracks", value: "\(tracksPlayed.count)", icon: "music.note.list", color: .purple)
                    }
                    .padding(.horizontal)
                    
                    // Tracks played section
                    if !tracksPlayed.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Tracks Played")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(tracksPlayed.prefix(10)) { track in
                                HStack {
                                    AsyncImage(url: track.artworkURL) { image in
                                        image.resizable()
                                    } placeholder: {
                                        Color.gray.opacity(0.3)
                                    }
                                    .frame(width: 44, height: 44)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    
                                    VStack(alignment: .leading) {
                                        Text(track.title)
                                            .font(.subheadline)
                                            .lineLimit(1)
                                        Text(track.artist)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                    
                                    Spacer()
                                    
                                    if let bpm = track.bpm {
                                        Text("\(Int(bpm))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.bottom, 40)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                    .fontWeight(.semibold)
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
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
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

