import XCTest
@testable import PulseTempo

final class IntegrationFlowTests: XCTestCase {

    private let onboardingSuiteName = "IntegrationFlowTests.OnboardingFlow"
    private let playlistKey = "selectedPlaylistIds"
    private var onboardingDefaults: UserDefaults!
    private var onboardingStorage: PlaylistStorageManager!
    private var homeViewModel: HomeViewModel?

    override func setUp() {
        super.setUp()

        UserDefaults.standard.set(["standard-sentinel"], forKey: playlistKey)

        guard let defaults = UserDefaults(suiteName: onboardingSuiteName) else {
            XCTFail("Failed to create user defaults suite")
            return
        }

        onboardingDefaults = defaults
        onboardingDefaults.removePersistentDomain(forName: onboardingSuiteName)
        onboardingStorage = PlaylistStorageManager(userDefaults: onboardingDefaults, suiteName: onboardingSuiteName)
    }

    override func tearDown() {
        homeViewModel = nil
        onboardingStorage = nil

        onboardingDefaults?.removePersistentDomain(forName: onboardingSuiteName)
        onboardingDefaults = nil

        UserDefaults.standard.removeObject(forKey: playlistKey)

        super.tearDown()
    }
    
    func testOnboardingFlowPersistsPlaylists() {
        let mockMusic = MockMusicService()
        let playlists = [MusicPlaylist(id: "p1", name: "Warmup", trackCount: 2, artwork: nil)]
        mockMusic.fetchUserPlaylistsHandler = { completion in completion(.success(playlists)) }

        homeViewModel = HomeViewModel(musicService: mockMusic, storageManager: onboardingStorage)
        homeViewModel?.saveSelectedPlaylists(playlists.map { $0.id })
        XCTAssertTrue(onboardingStorage.hasSelectedPlaylists)

        XCTAssertEqual(onboardingStorage.loadSelectedPlaylists(), playlists.map { $0.id })
        XCTAssertEqual(onboardingDefaults.stringArray(forKey: playlistKey), playlists.map { $0.id })
        XCTAssertEqual(UserDefaults.standard.stringArray(forKey: playlistKey), ["standard-sentinel"], "Should avoid reading from .standard during onboarding persistence")

        homeViewModel?.refreshPlaylists()
        waitForMainQueue()

        XCTAssertEqual(homeViewModel?.selectedPlaylists, playlists)
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
