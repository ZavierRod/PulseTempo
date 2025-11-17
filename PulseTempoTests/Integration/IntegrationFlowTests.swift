import XCTest
@testable import PulseTempo

final class IntegrationFlowTests: XCTestCase {
    
    func testOnboardingFlowPersistsPlaylists() {
        let storage = MockPlaylistStorageManager()
        let mockMusic = MockMusicService()
        let playlists = [MusicPlaylist(id: "p1", name: "Warmup", trackCount: 2, artwork: nil)]
        mockMusic.fetchUserPlaylistsHandler = { completion in completion(.success(playlists)) }

        let homeViewModel = HomeViewModel(musicService: mockMusic, storageManager: storage)
        homeViewModel.saveSelectedPlaylists(playlists.map { $0.id })
        XCTAssertTrue(storage.hasSelectedPlaylists)

        homeViewModel.refreshPlaylists()
        waitForMainQueue()

        XCTAssertEqual(homeViewModel.selectedPlaylists, playlists)
    }

    func testWorkoutFlowNavigationBetweenTracks() {
        let mockMusic = MockMusicService()
        let heartRate = MockHeartRateService()
        let tracks = [
            Track(id: "1", title: "Warmup", artist: "A", durationSeconds: 200, bpm: 100),
            Track(id: "2", title: "Push", artist: "B", durationSeconds: 210, bpm: 150)
        ]

        let runViewModel = RunSessionViewModel(tracks: tracks, heartRateService: heartRate, musicService: mockMusic)
        runViewModel.startRun()
        waitForMainQueue()

        heartRate.sendHeartRate(155)
        runViewModel.skipToNextTrack()
        waitForMainQueue()

        XCTAssertTrue(mockMusic.playCallCount >= 2)
        XCTAssertFalse(runViewModel.tracksPlayed.isEmpty)
    }

    func testPlaylistPersistenceIntegration() {
        let suiteName = "IntegrationTests"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create user defaults suite")
        }
        
        // Clean up before test
        defaults.removePersistentDomain(forName: suiteName)

        let storage = PlaylistStorageManager(userDefaults: defaults, suiteName: suiteName)
        storage.clearSelectedPlaylists()
        storage.saveSelectedPlaylists(["abc"])

        let reloaded = PlaylistStorageManager(userDefaults: defaults, suiteName: suiteName)
        XCTAssertEqual(reloaded.loadSelectedPlaylists(), ["abc"])
        
        // Clean up after test
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func waitForMainQueue() {
        let expectation = expectation(description: "waitForMainQueue")
        DispatchQueue.main.async { expectation.fulfill() }
        wait(for: [expectation], timeout: 1.0)
    }
}
