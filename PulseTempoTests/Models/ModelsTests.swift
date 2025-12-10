import XCTest
@testable import PulseTempo

final class ModelsTests: XCTestCase {
    
    // MARK: - Track Tests
    
    func testTrackInitialization() {
        let track = Track(
            id: "123",
            title: "Test Song",
            artist: "Test Artist",
            durationSeconds: 180,
            bpm: 120
        )
        
        XCTAssertEqual(track.id, "123")
        XCTAssertEqual(track.title, "Test Song")
        XCTAssertEqual(track.artist, "Test Artist")
        XCTAssertEqual(track.durationSeconds, 180)
        XCTAssertEqual(track.bpm, 120)
        XCTAssertFalse(track.isSkipped)
    }
    
    func testTrackInitializationWithNilBPM() {
        let track = Track(
            id: "456",
            title: "Unknown BPM",
            artist: "Artist",
            durationSeconds: 200,
            bpm: nil
        )
        
        XCTAssertNil(track.bpm)
    }
    
    func testTrackEquality() {
        let track1 = Track(id: "1", title: "Song", artist: "Artist", durationSeconds: 180, bpm: 120)
        let track2 = Track(id: "1", title: "Song", artist: "Artist", durationSeconds: 180, bpm: 120)
        let track3 = Track(id: "2", title: "Different", artist: "Artist", durationSeconds: 180, bpm: 120)
        
        XCTAssertEqual(track1, track2)
        XCTAssertNotEqual(track1, track3)
    }
    
    func testTrackHashable() {
        let track1 = Track(id: "1", title: "Song", artist: "Artist", durationSeconds: 180, bpm: 120)
        let track2 = Track(id: "1", title: "Song", artist: "Artist", durationSeconds: 180, bpm: 120)
        let track3 = Track(id: "2", title: "Different", artist: "Artist", durationSeconds: 180, bpm: 120)
        
        var set = Set<Track>()
        set.insert(track1)
        set.insert(track2) // Should not add duplicate
        set.insert(track3)
        
        XCTAssertEqual(set.count, 2)
        XCTAssertTrue(set.contains(track1))
        XCTAssertTrue(set.contains(track3))
    }
    
    // MARK: - Playlist Tests
    
    func testPlaylistInitialization() {
        let tracks = [
            Track(id: "1", title: "Song 1", artist: "Artist", durationSeconds: 180, bpm: 120),
            Track(id: "2", title: "Song 2", artist: "Artist", durationSeconds: 200, bpm: 130)
        ]
        
        let playlist = Playlist(id: "p1", name: "My Playlist", tracks: tracks)
        
        XCTAssertEqual(playlist.id, "p1")
        XCTAssertEqual(playlist.name, "My Playlist")
        XCTAssertEqual(playlist.tracks.count, 2)
        XCTAssertEqual(playlist.tracks, tracks)
    }
    
    func testPlaylistEquality() {
        let tracks = [
            Track(id: "1", title: "Song", artist: "Artist", durationSeconds: 180, bpm: 120)
        ]
        
        let playlist1 = Playlist(id: "p1", name: "Playlist", tracks: tracks)
        let playlist2 = Playlist(id: "p1", name: "Playlist", tracks: tracks)
        let playlist3 = Playlist(id: "p2", name: "Different", tracks: tracks)
        
        XCTAssertEqual(playlist1, playlist2)
        XCTAssertNotEqual(playlist1, playlist3)
    }
    
    func testPlaylistHashable() {
        let tracks = [
            Track(id: "1", title: "Song", artist: "Artist", durationSeconds: 180, bpm: 120)
        ]
        
        let playlist1 = Playlist(id: "p1", name: "Playlist", tracks: tracks)
        let playlist2 = Playlist(id: "p1", name: "Playlist", tracks: tracks)
        let playlist3 = Playlist(id: "p2", name: "Different", tracks: tracks)
        
        var set = Set<Playlist>()
        set.insert(playlist1)
        set.insert(playlist2) // Should not add duplicate
        set.insert(playlist3)
        
        XCTAssertEqual(set.count, 2)
        XCTAssertTrue(set.contains(playlist1))
        XCTAssertTrue(set.contains(playlist3))
    }
    
    // MARK: - RunMode Tests
    
    func testRunModeAllCases() {
        let allCases = RunMode.allCases
        
        XCTAssertEqual(allCases.count, 3)
        XCTAssertTrue(allCases.contains(.steadyTempo))
        XCTAssertTrue(allCases.contains(.progressiveBuild))
        XCTAssertTrue(allCases.contains(.recovery))
    }
    
    func testRunModeDisplayNames() {
        XCTAssertEqual(RunMode.steadyTempo.displayName, "Steady Tempo")
        XCTAssertEqual(RunMode.progressiveBuild.displayName, "Progressive Build")
        XCTAssertEqual(RunMode.recovery.displayName, "Recovery")
    }
    
    func testRunModeRawValue() {
        XCTAssertEqual(RunMode.steadyTempo.rawValue, "steadyTempo")
        XCTAssertEqual(RunMode.progressiveBuild.rawValue, "progressiveBuild")
        XCTAssertEqual(RunMode.recovery.rawValue, "recovery")
    }
    
    func testRunModeIdentifiable() {
        // Test that RunMode conforms to Identifiable via its id property
        XCTAssertEqual(RunMode.steadyTempo.id, "steadyTempo")
        XCTAssertEqual(RunMode.progressiveBuild.id, "progressiveBuild")
        XCTAssertEqual(RunMode.recovery.id, "recovery")
    }
    
    // MARK: - RunSessionState Tests
    
    func testRunSessionStateAllCases() {
        let notStarted = RunSessionState.notStarted
        let active = RunSessionState.active
        let paused = RunSessionState.paused
        let completed = RunSessionState.completed
        
        XCTAssertNotNil(notStarted)
        XCTAssertNotNil(active)
        XCTAssertNotNil(paused)
        XCTAssertNotNil(completed)
    }
    
    func testRunSessionStateDisplayNames() {
        XCTAssertEqual(RunSessionState.notStarted.displayName, "Not Started")
        XCTAssertEqual(RunSessionState.active.displayName, "Active")
        XCTAssertEqual(RunSessionState.paused.displayName, "Paused")
        XCTAssertEqual(RunSessionState.completed.displayName, "Completed")
    }
    
    func testRunSessionStateRawValue() {
        XCTAssertEqual(RunSessionState.notStarted.rawValue, "notStarted")
        XCTAssertEqual(RunSessionState.active.rawValue, "active")
        XCTAssertEqual(RunSessionState.paused.rawValue, "paused")
        XCTAssertEqual(RunSessionState.completed.rawValue, "completed")
    }
}
