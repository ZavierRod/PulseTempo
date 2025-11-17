import XCTest
@testable import PulseTempo

final class HomeViewModelTests: XCTestCase {
    private var mockMusicService: MockMusicService!
    private var mockStorage: MockPlaylistStorageManager!
    private var viewModel: HomeViewModel!

    override func setUp() {
        super.setUp()
        mockMusicService = MockMusicService()
        mockStorage = MockPlaylistStorageManager()
        viewModel = HomeViewModel(musicService: mockMusicService, storageManager: mockStorage)
    }

    override func tearDown() {
        viewModel = nil
        mockMusicService = nil
        mockStorage = nil
        super.tearDown()
    }

    func testFetchTracksForWorkoutReturnsErrorWhenNoSelection() {
        let expectation = expectation(description: "fetchTracks")

        viewModel.fetchTracksForWorkout { result in
            switch result {
            case .success:
                XCTFail("Expected failure when no playlists are selected")
            case .failure:
                break
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testFetchTracksForWorkoutAggregatesTracks() {
        let playlistId = "playlist-1"
        mockStorage.saveSelectedPlaylists([playlistId])

        let expectation = expectation(description: "fetchTracksSuccess")
        let tracks = [Track(id: "1", title: "Song", artist: "Artist", durationSeconds: 200, bpm: 120)]
        mockMusicService.fetchTracksHandler = { _, completion in completion(.success(tracks)) }

        viewModel.fetchTracksForWorkout { result in
            switch result {
            case .success(let returnedTracks):
                XCTAssertEqual(returnedTracks, tracks)
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testLoadingPlaylistsFiltersBySavedIds() {
        mockStorage.saveSelectedPlaylists(["one", "two"])

        let playlistOne = MusicPlaylist(id: "one", name: "P1", trackCount: 1)
        let playlistTwo = MusicPlaylist(id: "two", name: "P2", trackCount: 2)
        let playlistThree = MusicPlaylist(id: "three", name: "P3", trackCount: 3)

        mockMusicService.fetchUserPlaylistsHandler = { completion in
            completion(.success([playlistOne, playlistTwo, playlistThree]))
        }

        viewModel.refreshPlaylists()
        waitForMainQueue()

        XCTAssertEqual(viewModel.selectedPlaylists, [playlistOne, playlistTwo])
        XCTAssertEqual(viewModel.totalTrackCount, 3)
    }

    private func waitForMainQueue() {
        let expectation = expectation(description: "waitForMainQueue")
        DispatchQueue.main.async {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }
}
