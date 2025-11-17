//
//  PlaylistOverviewCard.swift
//  PulseTempo
//
//  Created by Zavier Rodrigues on 11/17/25.
//

import SwiftUI

/// Reusable card component for displaying playlist overview on home screen
struct PlaylistOverviewCard: View {
    let playlist: MusicPlaylist
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
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
                    
                    // Only show track count if available (> 0)
                    if playlist.trackCount > 0 {
                        Text("\(playlist.trackCount) \(playlist.trackCount == 1 ? "song" : "songs")")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Chevron indicator
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.8))
                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#if DEBUG
struct PlaylistOverviewCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 12) {
            PlaylistOverviewCard(
                playlist: MusicPlaylist(
                    id: "1",
                    name: "Running Mix",
                    trackCount: 42,
                    artwork: nil
                ),
                onTap: {
                    print("Playlist tapped")
                }
            )
            
            PlaylistOverviewCard(
                playlist: MusicPlaylist(
                    id: "2",
                    name: "Cardio Hits",
                    trackCount: 28,
                    artwork: nil
                ),
                onTap: {
                    print("Playlist tapped")
                }
            )
        }
        .padding()
        .background(Color.gray.opacity(0.1))
    }
}
#endif
