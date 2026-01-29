//
//  PlaylistSelectionView.swift
//  PulseTempo
//
//  Created by Zavier Rodrigues on 11/10/25.
//

import SwiftUI

/// View for selecting playlists from user's Apple Music library
/// Displays all available playlists with option to view songs in each
struct PlaylistSelectionView: View {
    
    // MARK: - Properties
    
    /// View model managing playlist data and selection
    @StateObject private var viewModel = PlaylistSelectionViewModel()
    
    /// Navigation state for showing playlist songs
    @State private var selectedPlaylistForViewing: MusicPlaylist?
    
    /// Callback when user confirms playlist selection
    var onPlaylistsSelected: (([Track]) -> Void)?
    
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
                
                VStack(spacing: 0) {
                    // Header
                    headerSection
                    
                    // Content
                    if viewModel.isLoading {
                        loadingView
                    } else if let error = viewModel.errorMessage {
                        errorView(error)
                    } else if viewModel.playlists.isEmpty {
                        emptyStateView
                    } else {
                        playlistListView
                    }
                    
                    // Bottom action bar (if playlists selected)
                    if !viewModel.selectedPlaylistIds.isEmpty {
                        bottomActionBar
                    }
                }
                
                // Analysis Overlay
                if viewModel.isAnalyzing {
                    analysisOverlay
                }
            }
            .navigationTitle("My Playlists")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // Load saved playlist selections
                let savedIds = PlaylistStorageManager.shared.loadSelectedPlaylists()
                viewModel.selectedPlaylistIds = Set(savedIds)
                
                // Fetch playlists from Apple Music
                viewModel.fetchPlaylists()
            }
            .sheet(item: $selectedPlaylistForViewing) { playlist in
                PlaylistSongsView(
                    playlist: playlist,
                    onDismiss: {
                        selectedPlaylistForViewing = nil
                    }
                )
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Select Playlists")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("Choose playlists for your workout")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)
        }
        .background(Color.white.opacity(0.5))
    }
    
    // MARK: - Playlist List View
    
    private var playlistListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.playlists) { playlist in
                    PlaylistCard(
                        playlist: playlist,
                        isSelected: viewModel.isPlaylistSelected(playlist.id),
                        onToggleSelection: {
                            viewModel.togglePlaylistSelection(playlist.id)
                        },
                        onViewSongs: {
                            selectedPlaylistForViewing = playlist
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .padding(.bottom, viewModel.selectedPlaylistIds.isEmpty ? 0 : 80)
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.blue)
            
            Text("Loading playlists...")
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
            
            Text("Error Loading Playlists")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: { viewModel.fetchPlaylists() }) {
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
            
            Text("No Playlists Found")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Create some playlists in Apple Music to get started.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Bottom Action Bar
    
    private var bottomActionBar: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(viewModel.selectedPlaylistIds.count) playlists selected")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("~\(viewModel.estimatedTrackCount) songs")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: confirmSelection) {
                    Text("Continue")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [Color.blue, Color.purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                        .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.white.opacity(0.95))
        }
        }

    
    // MARK: - Analysis Overlay
    
    /// Full-screen overlay that blocks all interaction while BPM analysis is in progress
    private var analysisOverlay: some View {
        ZStack {
            // Dimmed background that blocks interaction
            Color.black.opacity(0.6)
                .ignoresSafeArea()
            
            // Centered analysis card
            VStack(spacing: 20) {
                // Animated music waveform icon
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                    .symbolEffect(.pulse, options: .repeating)
                
                Text("Analyzing BPM")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Please wait while we analyze the tempo of your songs...")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.2)
                    .padding(.top, 8)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(white: 0.15))
                    .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
            )
            .padding(.horizontal, 40)
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.3), value: viewModel.isAnalyzing)
    }
    
    // MARK: - Helper Methods
    
    /// Confirm playlist selection and fetch all tracks
    private func confirmSelection() {
        // Save selected playlist IDs to persistent storage
        let playlistIds = Array(viewModel.selectedPlaylistIds)
        PlaylistStorageManager.shared.saveSelectedPlaylists(playlistIds)
        
        // Fetch tracks and wait for BPM analysis to complete before navigating
        // The loading overlay will be shown automatically while isAnalyzing is true
        viewModel.getSelectedTracks { result in
            switch result {
            case .success(let tracks):
                onPlaylistsSelected?(tracks)
            case .failure(let error):
                viewModel.errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Playlist Card Component

/// Card component for displaying a playlist with selection and view options
struct PlaylistCard: View {
    let playlist: MusicPlaylist
    let isSelected: Bool
    let onToggleSelection: () -> Void
    let onViewSongs: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Selection checkbox
            Button(action: onToggleSelection) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isSelected ? Color.blue : Color.clear)
                        )
                    
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // Playlist icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.6), Color.blue.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                
                Image(systemName: "music.note.list")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
            }
            
            // Playlist info
            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text("\(playlist.trackCount) \(playlist.trackCount == 1 ? "song" : "songs")")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // View songs button
            Button(action: onViewSongs) {
                HStack(spacing: 4) {
                    Text("View")
                        .font(.system(size: 14, weight: .medium))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.1))
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.8))
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
}

// MARK: - Preview

#if DEBUG
struct PlaylistSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        PlaylistSelectionView { tracks in
            print("Selected \(tracks.count) tracks")
        }
    }
}
#endif
