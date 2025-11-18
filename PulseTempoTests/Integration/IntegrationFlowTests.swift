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
        onboardingStorage = PlaylistStorageManager(userDefaults: onboardingDefaults, suiteName: onboardingSuiteName)
        // Clear any existing data safely
        onboardingStorage.clearSelectedPlaylists()
    }

    override func tearDown() {
        homeViewModel = nil
        
        // Clear data safely without removing the entire domain
        onboardingStorage?.clearSelectedPlaylists()
        onboardingStorage = nil
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

    @MainActor func testWorkoutFlowNavigationBetweenTracks() {
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
        
        // Properly stop the run to clean up timers and queues
        runViewModel.stopRun()
        waitForMainQueue()
    }

    func testPlaylistPersistenceIntegration() {
        // Use mock storage to avoid UserDefaults suite memory issues
        let storage = MockPlaylistStorageManager()
        
        storage.saveSelectedPlaylists(["abc", "def"])
        XCTAssertTrue(storage.hasSelectedPlaylists)
        XCTAssertEqual(storage.loadSelectedPlaylists(), ["abc", "def"])
        
        storage.clearSelectedPlaylists()
        XCTAssertFalse(storage.hasSelectedPlaylists)
        XCTAssertTrue(storage.loadSelectedPlaylists().isEmpty)
    }

    private func waitForMainQueue() {
        let expectation = expectation(description: "waitForMainQueue")
        DispatchQueue.main.async { expectation.fulfill() }
        wait(for: [expectation], timeout: 1.0)
    }
}
