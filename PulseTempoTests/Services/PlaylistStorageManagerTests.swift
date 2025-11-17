import XCTest
@testable import PulseTempo

final class PlaylistStorageManagerTests: XCTestCase {
    private var userDefaults: UserDefaults!
    private var storageManager: PlaylistStorageManager!

    override func setUp() {
        super.setUp()
        userDefaults = UserDefaults(suiteName: "PlaylistStorageManagerTests")
        userDefaults.removePersistentDomain(forName: "PlaylistStorageManagerTests")
        storageManager = PlaylistStorageManager(userDefaults: userDefaults)
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: "PlaylistStorageManagerTests")
        userDefaults = nil
        storageManager = nil
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
        storageManager.saveSelectedPlaylists(["10", "20"])
        let newManager = PlaylistStorageManager(userDefaults: userDefaults)
        XCTAssertEqual(newManager.loadSelectedPlaylists(), ["10", "20"])
    }

    func testHandlesInvalidDataGracefully() {
        userDefaults.set("not-an-array", forKey: "selectedPlaylistIds")
        let loaded = storageManager.loadSelectedPlaylists()
        XCTAssertTrue(loaded.isEmpty)
    }
}
