//
//  Models.swift
//  PulseTempo
//
//  Created by Zavier Rodrigues on 11/4/25.
//

import Foundation

struct Track: Identifiable, Equatable, Hashable {
    let id: String
    let title: String
    let artist: String
    let durationSeconds: Int
    let bpm: Int?
    var isSkipped: Bool = false
}

struct Playlist: Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    var tracks: [Track]
}

enum RunMode: String, CaseIterable, Identifiable {
    case steadyTempo
    case progressiveBuild
    case recovery
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .steadyTempo:
            return "Steady Tempo"
        case .progressiveBuild:
            return "Progressive Build"
        case .recovery:
            return "Recovery"
        }
    }
}
