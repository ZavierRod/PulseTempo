//
//  RunSessionViewModel.swift
//  PulseTempo
//
//  Created by Zavier Rodrigues on 11/4/25.
//

import Foundation
import SwiftUI
import Combine

final class RunSessionViewModel: ObservableObject {
    @Published var isPlaying: Bool = true
    @Published var currentTrack: Track?
    let runMode: RunMode = .steadyTempo
    
    private var tracks: [Track] = []
    private var currentIndex: Int = 0
    
    init() {
        setupFakePlaylist()
        currentTrack = tracks.first
    }
    
    private func setupFakePlaylist() {
        tracks = [
            Track(
                id: "1",
                title: "Eye of the Tiger",
                artist: "Survivor",
                durationSeconds: 245,
                bpm: 109
            ),
            Track(
                id: "2",
                title: "Stronger",
                artist: "Kanye West",
                durationSeconds: 312,
                bpm: 104
            ),
            Track(
                id: "3",
                title: "Lose Yourself",
                artist: "Eminem",
                durationSeconds: 326,
                bpm: 171
            ),
            Track(
                id: "4",
                title: "Can't Stop",
                artist: "Red Hot Chili Peppers",
                durationSeconds: 269,
                bpm: 126
            ),
            Track(
                id: "5",
                title: "Till I Collapse",
                artist: "Eminem",
                durationSeconds: 297,
                bpm: 166
            ),
            Track(
                id: "6",
                title: "Thunder",
                artist: "Imagine Dragons",
                durationSeconds: 187,
                bpm: 85
            )
        ]
    }
    
    func togglePlayPause() {
        isPlaying.toggle()
    }
    
    func skipToNextTrack(approximateHeartRate: Int? = nil) {
        guard !tracks.isEmpty else { return }
        
        if let heartRate = approximateHeartRate {
            // Find the best track based on BPM matching
            let availableTracks = tracks.enumerated().filter { $0.element.isSkipped == false }

            if let bestMatch = availableTracks.min(by: { lhs, rhs in
                let lhsDist = lhs.element.bpm.map { abs($0 - heartRate) } ?? 999
                let rhsDist = rhs.element.bpm.map { abs($0 - heartRate) } ?? 999
                return lhsDist < rhsDist
            }) {
                currentIndex = bestMatch.offset
                currentTrack = bestMatch.element
            }
        } else {
            // Just move to next track circularly
            currentIndex = (currentIndex + 1) % tracks.count
            currentTrack = tracks[currentIndex]
        }
    }
}
