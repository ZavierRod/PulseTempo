//
//  Models.swift
//  PulseTempo
//
//  Created by Zavier Rodrigues on 11/4/25.
//

// Foundation provides basic data types and utilities
// Similar to Python's built-in types and standard library
import Foundation

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
//
// PROTOCOLS:
// - String: the raw value type (each case has a string value)
// - CaseIterable: allows looping through all cases (like list(RunMode) in Python)
// - Identifiable: has an id property
enum RunMode: String, CaseIterable, Identifiable {
    // CASES (the possible values)
    case steadyTempo          // Maintain consistent pace
    case progressiveBuild     // Gradually increase intensity
    case recovery             // Low intensity recovery run
    
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
            return "Steady Tempo"          // Return this string
        case .progressiveBuild:            // If it's progressiveBuild
            return "Progressive Build"     // Return this string
        case .recovery:                    // If it's recovery
            return "Recovery"              // Return this string
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
