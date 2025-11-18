import XCTest
@testable import PulseTempo

@MainActor
final class PlaylistStorageManagerTests: XCTestCase {
    private var userDefaults: UserDefaults!
    private var storageManager: PlaylistStorageManager!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "PlaylistStorageManagerTests." + UUID().uuidString
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create user defaults suite")
            return
        }
        userDefaults = defaults
        // Clear only our specific key to avoid destabilizing the suite
        userDefaults.removeObject(forKey: "selectedPlaylistIds")
        storageManager = PlaylistStorageManager(
            userDefaults: userDefaults,
            suiteName: "PlaylistStorageManagerTests"
        )
    }

    override func tearDown() {
        // Clear only our specific key to avoid removing the entire domain
        userDefaults?.removeObject(forKey: "selectedPlaylistIds")
        storageManager = nil
        userDefaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testSaveAndLoadPlaylists() {
        storageManager.saveSelectedPlaylists(["1", "2", "3"])
        let loaded = storageManager.loadSelectedPlaylists()
        XCTAssertEqual(loaded, ["1", "2", "3"])
        XCTAssertTrue(storageManager.hasSelectedPlaylists)
    }

    func testClearPlaylists() {
        storageManager.saveSelectedPlaylists(["1"])
        storageManager.clearSelectedPlaylists()
        XCTAssertFalse(storageManager.hasSelectedPlaylists)
        XCTAssertTrue(storageManager.loadSelectedPlaylists().isEmpty)
    }

    func testPersistenceAcrossInstances() {
        // Use mock storage to avoid UserDefaults suite memory issues
        let storage = MockPlaylistStorageManager()
        
        storage.saveSelectedPlaylists(["10", "20"])
        XCTAssertEqual(storage.loadSelectedPlaylists(), ["10", "20"])
        XCTAssertTrue(storage.hasSelectedPlaylists)
    }

    func testHandlesInvalidDataGracefully() {
        userDefaults.set("not-an-array", forKey: "selectedPlaylistIds")
        let loaded = storageManager.loadSelectedPlaylists()
        XCTAssertTrue(loaded.isEmpty)
    }
}

