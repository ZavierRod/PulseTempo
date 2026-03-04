//
//  PlaylistSelectionView.swift
//  inSync
//
//  Created by Zavier Rodrigues on 11/10/25.
//

import SwiftUI
import MusicKit

/// View for selecting playlists from user's Apple Music library
/// Displays all available playlists with option to view songs in each
struct PlaylistSelectionView: View {
    
    // MARK: - Properties
    
    /// View model managing playlist data and selection
    @StateObject private var viewModel = PlaylistSelectionViewModel()
    
    /// Navigation state for showing playlist songs
    @State private var selectedPlaylistForViewing: MusicPlaylist?
    
    /// Callback whenever selected playlist IDs are updated
    var onSelectionChanged: (() -> Void)? = nil
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                GradientBackground()
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 30) {
                        headerSection
                        
                        if viewModel.isLoading {
                            loadingView
                        } else if let error = viewModel.errorMessage {
                            errorView(error)
                        } else if viewModel.playlistSections.isEmpty {
                            emptyStateView
                        } else {
                            playlistShelvesView
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, 26)
                }
                
                if viewModel.isAnalyzing {
                    analysisOverlay
                }
            }
            .navigationTitle("Listen")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                let savedIds = PlaylistStorageManager.shared.loadSelectedPlaylists()
                viewModel.selectedPlaylistIds = Set(savedIds)
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
        VStack(alignment: .leading, spacing: 8) {
            Text("For Your Workout")
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(.white)
            
            Text("Single tap a playlist to view songs. Double tap to add/remove it from your workout playlists.")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
            
            if !viewModel.selectedPlaylistIds.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "music.note.list")
                    Text("\(viewModel.selectedPlaylistIds.count) added")
                    
                    if viewModel.estimatedTrackCount > 0 {
                        Text("•")
                        Text("~\(viewModel.estimatedTrackCount) songs")
                    }
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.13))
                )
            }
        }
    }
    
    // MARK: - Shelf Sections
    
    private var playlistShelvesView: some View {
        VStack(alignment: .leading, spacing: 28) {
            ForEach(viewModel.playlistSections) { section in
                VStack(alignment: .leading, spacing: 12) {
                    Text(section.title)
                        .font(.system(size: 42, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 14) {
                            ForEach(section.playlists) { playlist in
                                PlaylistShelfCard(
                                    playlist: playlist,
                                    isSelected: viewModel.isPlaylistSelected(playlist.id),
                                    onToggleSelection: {
                                        togglePlaylistForWorkout(playlist)
                                    },
                                    onOpenPlaylist: {
                                        selectedPlaylistForViewing = playlist
                                    }
                                )
                                .frame(width: 190)
                            }
                        }
                        .padding(.horizontal, 1)
                    }
                }
            }
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 14) {
            ProgressView()
                .scaleEffect(1.4)
                .tint(.white)
            
            Text("Loading playlists...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity, minHeight: 360)
    }
    
    // MARK: - Error View
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundColor(.orange)
            
            Text("Couldn't load playlists")
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(.white)
            
            Text(message)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.78))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            Button(action: { viewModel.fetchPlaylists() }) {
                Text("Try Again")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.red.opacity(0.9))
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, minHeight: 340)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "music.note.list")
                .font(.system(size: 44))
                .foregroundColor(.white.opacity(0.5))
            
            Text("No playlists available")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
            
            Text("Create playlists in Apple Music and return here.")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity, minHeight: 340)
    }
    
    // MARK: - Analysis Overlay
    
    /// Full-screen overlay that blocks all interaction while BPM analysis is in progress
    private var analysisOverlay: some View {
        ZStack {
            Color.black.opacity(0.72)
                .ignoresSafeArea()
            
            VStack(spacing: 18) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 52))
                    .foregroundColor(.red)
                    .symbolEffect(.pulse, options: .repeating)
                
                Text("Analyzing BPM")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Please wait while we analyze song tempo.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.2)
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(white: 0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 36)
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.25), value: viewModel.isAnalyzing)
    }
    
    // MARK: - Helper Methods
    
    /// Add or remove a playlist from the workout selection and persist immediately.
    private func togglePlaylistForWorkout(_ playlist: MusicPlaylist) {
        viewModel.togglePlaylistSelection(playlist.id)
        
        let playlistIds = Array(viewModel.selectedPlaylistIds)
        PlaylistStorageManager.shared.saveSelectedPlaylists(playlistIds)
        onSelectionChanged?()
    }
}

// MARK: - Playlist Shelf Card

/// Artwork-forward playlist card inspired by Apple Music home shelves.
private struct PlaylistShelfCard: View {
    let playlist: MusicPlaylist
    let isSelected: Bool
    let onToggleSelection: () -> Void
    let onOpenPlaylist: () -> Void
    
    private var subtitleText: String {
        if playlist.trackCount > 0 {
            return "\(playlist.trackCount) \(playlist.trackCount == 1 ? "song" : "songs")"
        }
        return playlist.source == .library ? "Your library" : "Apple Music"
    }
    
    private var sourceIcon: String {
        switch playlist.source {
        case .library:
            return "music.note.list"
        case .catalogPlaylist:
            return "apple.logo"
        case .station:
            return "dot.radiowaves.left.and.right"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomLeading) {
                artworkBlock
                statusChip
                    .padding(8)
            }
            
            Text(playlist.name)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(isSelected ? .white.opacity(0.6) : .white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 5) {
                Image(systemName: sourceIcon)
                    .font(.system(size: 11, weight: .semibold))
                Text(subtitleText)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(isSelected ? .white.opacity(0.45) : .white.opacity(0.72))
            
            Text(isSelected ? "Double tap to remove from workout playlists" : "Double tap to add to workout playlists")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(isSelected ? .green.opacity(0.9) : .white.opacity(0.5))
        }
        .contentShape(Rectangle())
        .gesture(
            TapGesture(count: 2)
                .onEnded {
                    onToggleSelection()
                }
                .exclusively(
                    before: TapGesture(count: 1)
                        .onEnded {
                            onOpenPlaylist()
                        }
                )
        )
    }
    
    private var statusChip: some View {
        HStack(spacing: 6) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "music.note.list")
                .font(.system(size: 14, weight: .bold))
            Text(isSelected ? "Added" : "View")
                .font(.system(size: 13, weight: .bold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(isSelected ? Color.gray.opacity(0.9) : Color.black.opacity(0.58))
        )
    }
    
    private var artworkBlock: some View {
        ZStack(alignment: .bottomLeading) {
            artwork
        }
    }
    
    private var artwork: some View {
        CachedAsyncImage(
            url: playlist.artwork?.url(width: 500, height: 500)
        ) { image in
            image
                .resizable()
                .scaledToFill()
                .frame(width: 190, height: 190)
                .clipped()
                .saturation(isSelected ? 0.0 : 1.0)
                .brightness(isSelected ? -0.08 : 0.0)
                .opacity(isSelected ? 0.62 : 1.0)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        } placeholder: {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.25, green: 0.11, blue: 0.14), Color(red: 0.08, green: 0.09, blue: 0.16)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 190, height: 190)
                
                Image(systemName: sourceIcon)
                    .font(.system(size: 34, weight: .medium))
                    .foregroundColor(.white.opacity(0.86))
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct PlaylistSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        PlaylistSelectionView()
    }
}
#endif

