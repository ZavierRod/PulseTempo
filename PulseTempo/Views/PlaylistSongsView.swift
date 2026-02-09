//
//  PlaylistSongsView.swift
//  inSync
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
    
    /// Whether the music search sheet is showing
    @State private var showingMusicSearch: Bool = false
    
    /// Music service for fetching tracks
    /// Music service for playback
    @ObservedObject private var musicService = MusicService.shared
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // White-to-black gradient background (inSync theme)
            GradientBackground()
            
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
        .onReceive(musicService.trackUpdatedPublisher) { updatedTrack in
            if let index = tracks.firstIndex(where: { $0.id == updatedTrack.id }) {
                tracks[index] = updatedTrack
            }
        }
        .sheet(isPresented: $showingMusicSearch) {
            MusicSearchView(playlistId: playlist.id) {
                // Refresh tracks after songs were added
                fetchTracks()
            }
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
                                .font(.bebasNeueSubheadline)
                            Text("Back")
                                .font(.bebasNeueBodySmall)
                        }
                        .foregroundColor(.red)
                    }
                }
                
                Spacer()
                
                // Add Songs button
                Button(action: { showingMusicSearch = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                        Text("Add Songs")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color.pink, Color.red],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
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
                    .font(.bebasNeueMedium)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                // Track count
                Text("\(tracks.count) \(tracks.count == 1 ? "song" : "songs")")
                    .font(.bebasNeueSubheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.bottom, 16)
        }
        .background(Color.black.opacity(0.2))
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
                .tint(.red)
            
            Text("Loading songs...")
                .font(.bebasNeueSubheadline)
                .foregroundColor(.white.opacity(0.8))
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
                .font(.bebasNeueTitle)
                .foregroundColor(.white)
            
            Text(message)
                .font(.bebasNeueSubheadline)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: fetchTracks) {
                Text("Try Again")
                    .font(.bebasNeueSubheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [Color.pink, Color.purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
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
                .font(.bebasNeueTitle)
                .foregroundColor(.white)
            
            Text("This playlist doesn't contain any songs.")
                .font(.bebasNeueSubheadline)
                .foregroundColor(.white.opacity(0.8))
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
        
        // Don't trigger BPM analysis when browsing - only analyze when playlist is confirmed for workout
        // BPM analysis happens in PlaylistSelectionViewModel.getSelectedTracks()
        musicService.fetchTracksFromPlaylist(playlistId: playlist.id, triggerBPMAnalysis: false) { result in
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
            // Album artwork or placeholder
            if let artworkURL = track.artworkURL {
                AsyncImage(url: artworkURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 50, height: 50)
                            .cornerRadius(8)
                    case .failure(_):
                        artworkPlaceholder
                    case .empty:
                        ProgressView()
                            .frame(width: 50, height: 50)
                    @unknown default:
                        artworkPlaceholder
                    }
                }
            } else {
                artworkPlaceholder
            }
            
            // Track info
            VStack(alignment: .leading, spacing: 4) {
                Text(track.title)
                    .font(.bebasNeueSubheadline)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text(track.artist)
                        .font(.bebasNeueCaption)
                        .foregroundColor(.white.opacity(0.7))
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
                        .foregroundColor(.red)
                    }
                }
            }
            
            Spacer()
            
            // Duration
            Text(formatDuration(track.durationSeconds))
                .font(.bebasNeueCaption)
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    /// Placeholder view for missing artwork
    private var artworkPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.red.opacity(0.1))
                .frame(width: 50, height: 50)
            
            Image(systemName: "music.note")
                .font(.system(size: 20))
                .foregroundColor(.red)
        }
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

