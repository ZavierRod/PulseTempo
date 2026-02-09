//
//  MusicSearchView.swift
//  PulseTempo
//
//  Created by Zavier Rodrigues on 2/9/26.
//

import SwiftUI

/// Sheet view for searching the Apple Music catalog and adding songs to a playlist
///
/// Presented from PlaylistSongsView when the user taps "+ Add Songs".
/// Displays a search bar, catalog results, and per-track add buttons.
struct MusicSearchView: View {
    
    // MARK: - Properties
    
    /// View model managing search state and playlist additions
    @StateObject private var viewModel: MusicSearchViewModel
    
    /// Callback when the sheet is dismissed — passes back tracks that were added
    var onSongsAdded: (([Track]) -> Void)?
    
    /// Tracks whether any songs were added (to trigger refresh)
    @State private var didAddSongs: Bool = false
    
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isSearchFocused: Bool
    
    // MARK: - Initialization
    
    init(playlistId: String, onSongsAdded: (([Track]) -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: MusicSearchViewModel(playlistId: playlistId))
        self.onSongsAdded = onSongsAdded
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                GradientBackground()
                
                VStack(spacing: 0) {
                    // Search bar
                    searchBar
                    
                    // Content
                    if viewModel.isSearching {
                        searchingView
                    } else if let error = viewModel.errorMessage {
                        errorView(error)
                    } else if viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        emptyPromptView
                    } else if viewModel.searchResults.isEmpty {
                        noResultsView
                    } else {
                        resultsList
                    }
                }
            }
            .navigationTitle("Add Songs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        if didAddSongs {
                            onSongsAdded?(viewModel.addedTracks)
                        }
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .onChange(of: viewModel.addedTrackIds) {
                didAddSongs = true
            }
        }
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white.opacity(0.5))
                .font(.system(size: 16))
            
            TextField("Search Apple Music...", text: $viewModel.searchQuery)
                .foregroundColor(.white)
                .font(.bebasNeueBody)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($isSearchFocused)
            
            if !viewModel.searchQuery.isEmpty {
                Button(action: { viewModel.clearSearch() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.5))
                        .font(.system(size: 16))
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .onAppear { isSearchFocused = true }
    }
    
    // MARK: - Results List
    
    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(viewModel.searchResults) { track in
                    SearchResultRow(
                        track: track,
                        isAdded: viewModel.addedTrackIds.contains(track.id),
                        isAdding: viewModel.isAdding,
                        onAdd: { viewModel.addTrack(track) }
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - State Views
    
    private var searchingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.red)
            
            Text("Searching...")
                .font(.bebasNeueSubheadline)
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyPromptView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.3))
            
            Text("Search Apple Music")
                .font(.bebasNeueTitle)
                .foregroundColor(.white)
            
            Text("Find songs to add to your playlist")
                .font(.bebasNeueSubheadline)
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var noResultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.3))
            
            Text("No Results")
                .font(.bebasNeueTitle)
                .foregroundColor(.white)
            
            Text("Try a different search term")
                .font(.bebasNeueSubheadline)
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("Something went wrong")
                .font(.bebasNeueTitle)
                .foregroundColor(.white)
            
            Text(message)
                .font(.bebasNeueSubheadline)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Search Result Row

/// A single search result with artwork, track info, and an add button
struct SearchResultRow: View {
    let track: Track
    let isAdded: Bool
    let isAdding: Bool
    let onAdd: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Album artwork
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
                            .tint(.white)
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
                
                Text(track.artist)
                    .font(.bebasNeueCaption)
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Duration
            Text(formatDuration(track.durationSeconds))
                .font(.bebasNeueCaption)
                .foregroundColor(.white.opacity(0.5))
            
            // Add button
            Button(action: onAdd) {
                if isAdded {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.red)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isAdded || isAdding)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
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
    
    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

// MARK: - Preview

#if DEBUG
struct MusicSearchView_Previews: PreviewProvider {
    static var previews: some View {
        MusicSearchView(playlistId: "preview-playlist-id")
    }
}
#endif
