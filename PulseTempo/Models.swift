//
//  Models.swift
//  PulseTempo
//
//  Created by Zavier Rodrigues on 11/4/25.
//

// Foundation provides basic data types and utilities
// Similar to Python's built-in types and standard library
import Foundation
import SwiftUI

// DATA MODEL: Track
// "struct" is like a Python dataclass or Pydantic model
// It's a lightweight container for data (similar to a class but with value semantics)
//
// Python equivalent:
// from dataclasses import dataclass
// @dataclass
// class Track:
//     id: str
//     title: str
//     artist: str
//     ...
//
// PROTOCOLS (after the colon):
// - Identifiable: means it has an "id" property (like having a primary key)
// - Equatable: allows comparing two Tracks with == (like Python's __eq__)
// - Hashable: allows using Track in sets/dictionaries (like Python's __hash__)
struct Track: Identifiable, Equatable, Hashable {
    // PROPERTIES (like class attributes in Python)
    // "let" = constant (immutable, like a Python variable you never reassign)
    // "var" = variable (mutable, can be changed)
    
    let id: String                    // Unique identifier for the track
    let title: String                 // Song title
    let artist: String                // Artist name
    let durationSeconds: Int          // How long the song is in seconds
    let bpm: Int?                     // Beats per minute (? means Optional - can be nil/None)
    let artworkURL: URL?              // Album artwork URL
    var isSkipped: Bool = false       // Has user skipped this? (default value = false)
    
    // Custom initializer with default value for artworkURL
    init(id: String, title: String, artist: String, durationSeconds: Int, bpm: Int?, artworkURL: URL? = nil, isSkipped: Bool = false) {
        self.id = id
        self.title = title
        self.artist = artist
        self.durationSeconds = durationSeconds
        self.bpm = bpm
        self.artworkURL = artworkURL
        self.isSkipped = isSkipped
    }
}

// DATA MODEL: Playlist
// A collection of tracks, similar to a Python class with a list of Track objects
//
// Python equivalent:
// @dataclass
// class Playlist:
//     id: str
//     name: str
//     tracks: List[Track]
struct Playlist: Identifiable, Equatable, Hashable {
    let id: String                    // Unique identifier for the playlist
    let name: String                  // Playlist name
    var tracks: [Track]               // Array of tracks ([Track] is like List[Track] in Python)
}

// ENUMERATION: RunMode
// "enum" is like Python's Enum class - a set of named constants
//
// Python equivalent:
// from enum import Enum
// class RunMode(Enum):
//     STEADY_TEMPO = "steadyTempo"
//     PROGRESSIVE_BUILD = "progressiveBuild"
//     RECOVERY = "recovery"
//     CADENCE_MATCHING = "cadenceMatching"
//
// PROTOCOLS:
// - String: the raw value type (each case has a string value)
// - CaseIterable: allows looping through all cases (like list(RunMode) in Python)
// - Identifiable: has an id property
enum RunMode: String, CaseIterable, Identifiable {
    // CASES (the possible values)
    case steadyTempo          // Maintain consistent pace (matches to heart rate)
    case progressiveBuild     // Gradually increase intensity
    case recovery             // Low intensity recovery run
    case cadenceMatching      // Match songs to running cadence (steps per minute)
    
    // COMPUTED PROPERTY: id
    // Returns the raw string value as the id
    // "rawValue" is the string representation ("steadyTempo", "progressiveBuild", etc.)
    var id: String { rawValue }
    
    // COMPUTED PROPERTY: displayName
    // Returns a human-readable name for display in the UI
    // "switch" is like Python's match/case (or if/elif/else)
    var displayName: String {
        switch self {                      // Check which case this is
        case .steadyTempo:                 // If it's steadyTempo
            return "Heart Rate"            // Return this string
        case .progressiveBuild:            // If it's progressiveBuild
            return "Progressive Build"     // Return this string
        case .recovery:                    // If it's recovery
            return "Recovery"              // Return this string
        case .cadenceMatching:             // If it's cadenceMatching
            return "Cadence"               // Return this string
        }
    }
    
    // COMPUTED PROPERTY: description
    // Returns a description of what this mode does
    var description: String {
        switch self {
        case .steadyTempo:
            return "Match songs to your heart rate"
        case .progressiveBuild:
            return "Gradually increase intensity"
        case .recovery:
            return "Low intensity recovery"
        case .cadenceMatching:
            return "Match songs to your running cadence"
        }
    }
    
    // COMPUTED PROPERTY: icon
    // Returns an SF Symbol name for this mode
    var icon: String {
        switch self {
        case .steadyTempo:
            return "heart.fill"
        case .progressiveBuild:
            return "chart.line.uptrend.xyaxis"
        case .recovery:
            return "leaf.fill"
        case .cadenceMatching:
            return "figure.run"
        }
    }
    
    // COMPUTED PROPERTY: color
    // Returns a color associated with this mode
    var color: String {
        switch self {
        case .steadyTempo:
            return "red"
        case .progressiveBuild:
            return "orange"
        case .recovery:
            return "green"
        case .cadenceMatching:
            return "cyan"
        }
    }
}

// ENUMERATION: RunSessionState
// Represents the current state of a run session
//
// Python equivalent:
// from enum import Enum
// class RunSessionState(Enum):
//     NOT_STARTED = "notStarted"
//     ACTIVE = "active"
//     PAUSED = "paused"
//     COMPLETED = "completed"
enum RunSessionState: String {
    case notStarted    // Run hasn't started yet
    case active        // Run is currently in progress
    case paused        // Run is temporarily paused
    case completed     // Run has finished
    
    var displayName: String {
        switch self {
        case .notStarted:
            return "Not Started"
        case .active:
            return "Active"
        case .paused:
            return "Paused"
        case .completed:
            return "Completed"
        }
    }
}

// ENUMERATION: HeartRateZone
// Represents heart rate training zones based on current BPM
enum HeartRateZone: String, CaseIterable {
    case rest           // < 100 BPM
    case warmUp         // 100-120 BPM
    case fatBurn        // 120-140 BPM
    case cardio         // 140-160 BPM
    case peak           // 160-180 BPM
    case max            // > 180 BPM
    
    var name: String {
        switch self {
        case .rest: return "Rest"
        case .warmUp: return "Warm Up"
        case .fatBurn: return "Fat Burn"
        case .cardio: return "Cardio"
        case .peak: return "Peak"
        case .max: return "Maximum"
        }
    }
    
    var color: Color {
        switch self {
        case .rest: return .gray
        case .warmUp: return .blue
        case .fatBurn: return .green
        case .cardio: return .yellow
        case .peak: return .orange
        case .max: return .red
        }
    }
    
    static func zone(for heartRate: Int) -> HeartRateZone {
        switch heartRate {
        case ..<100: return .rest
        case 100..<120: return .warmUp
        case 120..<140: return .fatBurn
        case 140..<160: return .cardio
        case 160..<180: return .peak
        default: return .max
        }
    }
}
