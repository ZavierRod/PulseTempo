import XCTest
@testable import PulseTempo

/// Tests for playlist persistence across app lifecycle
final class PlaylistPersistenceTests: XCTestCase {
    
    var storage: PlaylistStorageManager!
    
    override func setUp() {
        super.setUp()
        storage = PlaylistStorageManager.shared
        // Start with clean state
        storage.clearSelectedPlaylists()
    }
    
    override func tearDown() {
        storage.clearSelectedPlaylists()
        storage = nil
        super.tearDown()
    }
    
    func testSaveAndLoadPlaylists() {
        let playlistIds = ["playlist-1", "playlist-2", "playlist-3"]
        
        // Save playlists
        storage.saveSelectedPlaylists(playlistIds)
        
        // Load playlists
        let loadedIds = storage.loadSelectedPlaylists()
        
        // Verify
        XCTAssertEqual(Set(loadedIds), Set(playlistIds))
    }
    
    func testEmptyPlaylistStorage() {
        // Don't save anything
        let loadedIds = storage.loadSelectedPlaylists()
        
        // Should return empty array
        XCTAssertTrue(loadedIds.isEmpty)
        XCTAssertFalse(storage.hasSelectedPlaylists)
    }
    
    func testClearPlaylists() {
        // Save some playlists
        storage.saveSelectedPlaylists(["p1", "p2"])
        XCTAssertTrue(storage.hasSelectedPlaylists)
        
        // Clear them
        storage.clearSelectedPlaylists()
        
        // Verify cleared
        XCTAssertTrue(storage.loadSelectedPlaylists().isEmpty)
        XCTAssertFalse(storage.hasSelectedPlaylists)
    }
    
    func testOverwritePlaylists() {
        // Save initial playlists
        storage.saveSelectedPlaylists(["old-1", "old-2"])
        
        // Overwrite with new playlists
        let newPlaylists = ["new-1", "new-2", "new-3"]
        storage.saveSelectedPlaylists(newPlaylists)
        
        // Verify new playlists replace old ones
        let loadedIds = storage.loadSelectedPlaylists()
        XCTAssertEqual(Set(loadedIds), Set(newPlaylists))
        XCTAssertFalse(loadedIds.contains("old-1"))
        XCTAssertFalse(loadedIds.contains("old-2"))
    }
    
    func testMultipleSaveLoadCycles() {
        // Cycle 1
        storage.saveSelectedPlaylists(["cycle1-p1"])
        XCTAssertEqual(storage.loadSelectedPlaylists().count, 1)
        
        // Cycle 2
        storage.saveSelectedPlaylists(["cycle2-p1", "cycle2-p2"])
        XCTAssertEqual(storage.loadSelectedPlaylists().count, 2)
        
        // Cycle 3
        storage.saveSelectedPlaylists(["cycle3-p1", "cycle3-p2", "cycle3-p3"])
        let final = storage.loadSelectedPlaylists()
        XCTAssertEqual(final.count, 3)
        XCTAssertTrue(final.contains("cycle3-p1"))
    }
    
    func testPersistenceAcrossInstances() {
        let storage1 = PlaylistStorageManager.shared
        storage1.clearSelectedPlaylists()
        
        let playlistsIds = ["persist-1", "persist-2"]
        
        // Save with shared instance
        storage1.saveSelectedPlaylists(playlistsIds)
        
        // Access again via shared instance
        let storage2 = PlaylistStorageManager.shared
        let loadedIds = storage2.loadSelectedPlaylists()
        
        // Verify persistence
        XCTAssertEqual(Set(loadedIds), Set(playlistsIds))
        
        // Clean up
        storage2.clearSelectedPlaylists()
    }
    
    func testHasSelectedPlaylistsFlag() {
        // Initially should be false
        XCTAssertFalse(storage.hasSelectedPlaylists)
        
        // After saving, should be true
        storage.saveSelectedPlaylists(["test"])
        XCTAssertTrue(storage.hasSelectedPlaylists)
        
        // After clearing, should be false again
        storage.clearSelectedPlaylists()
        XCTAssertFalse(storage.hasSelectedPlaylists)
    }
}
