//
//  PlaylistSongsView.swift
//  PulseTempo
//
//  Created by Zavier Rodrigues on 11/10/25.
//

import SwiftUI

/// View for displaying songs from a selected playlist
/// Shows all tracks with their details in a scrollable list
struct PlaylistSongsView: View {
    
    // MARK: - Properties
    
    /// The playlist to display songs from
    let playlist: MusicPlaylist
    
    /// Callback when user wants to go back
    var onDismiss: (() -> Void)?
    
    // MARK: - State
    
    /// List of tracks fetched from the playlist
    @State private var tracks: [Track] = []
    
    /// Loading state while fetching tracks
    @State private var isLoading: Bool = false
    
    /// Error message if something goes wrong
    @State private var errorMessage: String?
    
    /// Music service for fetching tracks
    @StateObject private var musicService = MusicService()
    
    // MARK: - Body
    
    var body: some View {
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
            
            VStack(spacing: 0) {
                // Header
                headerSection
                
                // Content
                if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error)
                } else if tracks.isEmpty {
                    emptyStateView
                } else {
                    trackListView
                }
            }
        }
        .onAppear {
            fetchTracks()
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                // Back button
                if let dismiss = onDismiss {
                    Button(action: dismiss) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Back")
                                .font(.system(size: 17))
                        }
                        .foregroundColor(.blue)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            
            // Playlist info
            VStack(spacing: 8) {
                // Playlist icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [Color.purple.opacity(0.6), Color.blue.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                        .shadow(color: .purple.opacity(0.3), radius: 10, x: 0, y: 4)
                    
                    Image(systemName: "music.note.list")
                        .font(.system(size: 36))
                        .foregroundColor(.white)
                }
                
                // Playlist name
                Text(playlist.name)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                // Track count
                Text("\(tracks.count) \(tracks.count == 1 ? "song" : "songs")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 16)
        }
        .background(Color.white.opacity(0.5))
    }
    
    // MARK: - Track List View
    
    private var trackListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(tracks) { track in
                    TrackRow(track: track)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.blue)
            
            Text("Loading songs...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Error View
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("Error Loading Songs")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: fetchTracks) {
                Text("Try Again")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.list")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("No Songs Found")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("This playlist doesn't contain any songs.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Helper Methods
    
    /// Fetch tracks from the playlist
    private func fetchTracks() {
        isLoading = true
        errorMessage = nil
        
        musicService.fetchTracksFromPlaylist(playlistId: playlist.id) { result in
            DispatchQueue.main.async {
                isLoading = false
                
                switch result {
                case .success(let fetchedTracks):
                    tracks = fetchedTracks
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Track Row Component

/// Individual row component for displaying a track
struct TrackRow: View {
    let track: Track
    
    var body: some View {
        HStack(spacing: 12) {
            // Track number or music icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 44, height: 44)
                
                Image(systemName: "music.note")
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
            }
            
            // Track info
            VStack(alignment: .leading, spacing: 4) {
                Text(track.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text(track.artist)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    if let bpm = track.bpm {
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "metronome")
                                .font(.system(size: 10))
                            Text("\(bpm) BPM")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.blue)
                    }
                }
            }
            
            Spacer()
            
            // Duration
            Text(formatDuration(track.durationSeconds))
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.8))
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
    
    /// Format duration in seconds to MM:SS format
    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

// MARK: - Preview

#if DEBUG
struct PlaylistSongsView_Previews: PreviewProvider {
    static var previews: some View {
        PlaylistSongsView(
            playlist: MusicPlaylist(
                id: "preview-1",
                name: "Running Mix",
                trackCount: 25,
                artwork: nil
            ),
            onDismiss: {
                print("Dismiss tapped")
            }
        )
    }
}
#endif

