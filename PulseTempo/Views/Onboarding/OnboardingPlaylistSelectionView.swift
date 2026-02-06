//
//  OnboardingPlaylistSelectionView.swift
//  inSync
//
//  Created by Zavier Rodrigues on 11/10/25.
//

import SwiftUI
import MusicKit

/// Onboarding wrapper for playlist selection
/// Allows users to select playlists during the onboarding flow
struct OnboardingPlaylistSelectionView: View {
    
    // MARK: - Properties
    
    /// View model managing playlist data and selection
    @StateObject private var viewModel = PlaylistSelectionViewModel()
    
    /// Navigation state for showing playlist songs
    @State private var selectedPlaylistForViewing: MusicPlaylist?
    
    /// Callback when user confirms playlist selection
    var onPlaylistsSelected: ([Track]) -> Void
    
    /// Callback when user taps back
    var onBack: () -> Void
    
    /// Callback when user skips this step
    var onSkip: () -> Void
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // White-to-black gradient background (inSync theme)
            GradientBackground()
            
            VStack(spacing: 0) {
                // Header with back and skip buttons
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
                
                // Bottom action bar
                bottomActionBar
            }
            
            // Analysis Overlay (blocks interaction while analyzing BPM)
            if viewModel.isAnalyzing {
                analysisOverlay
            }
        }
        .onAppear {
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
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Navigation buttons
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.bebasNeueSubheadline)
                        Text("Back")
                            .font(.bebasNeueBodySmall)
                    }
                    .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                Button(action: onSkip) {
                    Text("Skip")
                        .font(.bebasNeueBodySmall)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            // Title and description
            VStack(spacing: 8) {
                Text("Choose Your Music")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("Select playlists to match your workout tempo")
                    .font(.bebasNeueBodySmall)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .padding(.bottom, 20)
        }
    }
    
    // MARK: - Playlist List View
    
    private var playlistListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.playlists) { playlist in
                    OnboardingPlaylistCard(
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
            .padding(.bottom, 100)
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)
            
            Text("Loading playlists...")
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
            
            Text("Error Loading Playlists")
                .font(.bebasNeueTitle)
                .foregroundColor(.white)
            
            Text(message)
                .font(.bebasNeueSubheadline)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: { viewModel.fetchPlaylists() }) {
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
                .foregroundColor(.white.opacity(0.6))
            
            Text("No Playlists Found")
                .font(.bebasNeueTitle)
                .foregroundColor(.white)
            
            Text("Create some playlists in Apple Music to get started, or skip this step for now.")
                .font(.bebasNeueSubheadline)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: onSkip) {
                Text("Skip for Now")
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
    
    // MARK: - Bottom Action Bar
    
    private var bottomActionBar: some View {
        VStack(spacing: 0) {
            if !viewModel.selectedPlaylistIds.isEmpty {
                // Selection info
                VStack(spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(viewModel.selectedPlaylistIds.count) playlists selected")
                                .font(.bebasNeueSubheadline)
                                .foregroundColor(.white)
                            
                            Text("~\(viewModel.estimatedTrackCount) songs")
                                .font(.bebasNeueCaption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    
                    // Continue button
                    Button(action: confirmSelection) {
                        HStack {
                            Text("Continue")
                                .font(.bebasNeueBody)
                            Image(systemName: "arrow.right")
                                .font(.bebasNeueSubheadline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                colors: [Color.pink, Color.purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                        .shadow(color: Color.pink.opacity(0.4), radius: 15, x: 0, y: 8)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
                .background(Color.black.opacity(0.2))
            } else {
                // Skip hint when nothing selected
                Text("Select playlists or skip to continue")
                    .font(.bebasNeueCaption)
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.vertical, 20)
            }
        }
    }
    
    // MARK: - Analysis Overlay
    
    /// Full-screen overlay that blocks all interaction while BPM analysis is in progress
    private var analysisOverlay: some View {
        ZStack {
            // Dimmed background that blocks interaction
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            // Centered analysis card
            VStack(spacing: 20) {
                // Animated music waveform icon
                Image(systemName: "waveform.circle.fill")
                    .font(.bebasNeueExtraLarge)
                    .foregroundColor(.pink)
                    .symbolEffect(.pulse, options: .repeating)
                
                Text("Analyzing BPM")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Please wait while we analyze the tempo of your songs...")
                    .font(.bebasNeueSubheadline)
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
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.15), Color(white: 0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
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
        
        viewModel.getSelectedTracks { result in
            switch result {
            case .success(let tracks):
                onPlaylistsSelected(tracks)
            case .failure(let error):
                viewModel.errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Onboarding Playlist Card Component

/// Card component for displaying a playlist in onboarding style
struct OnboardingPlaylistCard: View {
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
                        .stroke(isSelected ? Color.pink : Color.white.opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isSelected ? Color.pink : Color.clear)
                        )
                    
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // Playlist artwork or placeholder
            if let artwork = playlist.artwork,
               let url = artwork.url(width: 120, height: 120) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 56, height: 56)
                            .cornerRadius(8)
                    case .failure(_):
                        onboardingArtworkPlaceholder
                    case .empty:
                        ProgressView()
                            .tint(.white)
                            .frame(width: 56, height: 56)
                    @unknown default:
                        onboardingArtworkPlaceholder
                    }
                }
            } else {
                onboardingArtworkPlaceholder
            }
            
            // Playlist info
            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.name)
                    .font(.bebasNeueSubheadline)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text("\(playlist.trackCount) \(playlist.trackCount == 1 ? "song" : "songs")")
                    .font(.bebasNeueCaption)
                    .foregroundColor(.white.opacity(0.7))
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
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.2))
                )
            }
            .buttonStyle(PlainButtonStyle())
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
    
    /// Placeholder view for missing playlist artwork
    private var onboardingArtworkPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [Color.purple.opacity(0.6), Color.pink.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 56, height: 56)
            
            Image(systemName: "music.note.list")
                .font(.system(size: 24))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct OnboardingPlaylistSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingPlaylistSelectionView(
            onPlaylistsSelected: { tracks in
                print("Selected \(tracks.count) tracks")
            },
            onBack: {
                print("Back tapped")
            },
            onSkip: {
                print("Skip tapped")
            }
        )
    }
}
#endif
