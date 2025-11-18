import XCTest
@testable import PulseTempo

@MainActor
final class RunSessionViewModelTests: XCTestCase {
    private var mockMusicService: MockMusicService!
    private var mockHeartRateService: MockHeartRateService!
    private var viewModel: RunSessionViewModel!

    private let trackA = Track(id: "A", title: "Track A", artist: "Artist", durationSeconds: 200, bpm: 120)
    private let trackB = Track(id: "B", title: "Track B", artist: "Artist", durationSeconds: 210, bpm: 130)
    private let trackC = Track(id: "C", title: "Track C", artist: "Artist", durationSeconds: 180, bpm: 90)

    override func setUp() {
        super.setUp()
        mockMusicService = MockMusicService()
        mockHeartRateService = MockHeartRateService()
        viewModel = RunSessionViewModel(
            tracks: [trackA, trackB, trackC],
            heartRateService: mockHeartRateService,
            musicService: mockMusicService
        )
    }

    override func tearDown() {
        // Ensure any running sessions are stopped to clean up timers/observers
        viewModel?.stopRun()
        viewModel = nil
        mockMusicService = nil
        mockHeartRateService = nil
        super.tearDown()
    }

    func testSkipToNextTrackUpdatesHistoryAndPlayedIds() {
        viewModel.startRun()
        waitForQueueFlush()

        mockHeartRateService.sendHeartRate(128)
        viewModel.skipToNextTrack()
        waitForQueueFlush()

        let lastPlayedVMId = viewModel.tracksPlayed.last?.id
        let lastPlayedServiceId = mockMusicService.playedTracks.last?.id
        let containsLastPlayedServiceId = lastPlayedServiceId.map { viewModel.playedTrackIdsSnapshot.contains($0) } ?? false

        XCTAssertEqual(mockMusicService.playCallCount, 2, "Initial play + next skip should trigger two play calls")
        XCTAssertEqual(lastPlayedVMId, lastPlayedServiceId)
        XCTAssertTrue(containsLastPlayedServiceId)
    }

    func testSkipToPreviousTrackWithRapidCallsDebounces() {
        viewModel.startRun()
        waitForQueueFlush()

        viewModel.skipToNextTrack()
        waitForQueueFlush()

        let initialPlayCount = mockMusicService.playCallCount
        viewModel.skipToPreviousTrack()
        viewModel.skipToPreviousTrack()
        waitForQueueFlush()

        let currentTrackId = viewModel.currentTrack?.id
        let lastPlayedId = viewModel.tracksPlayed.last?.id

        XCTAssertEqual(mockMusicService.playCallCount, initialPlayCount + 1, "Debounce should block back-to-back previous calls")
        XCTAssertEqual(currentTrackId, trackA.id)
        XCTAssertEqual(lastPlayedId, trackA.id)
    }

    func testTrackHistoryManagementPreventsCrashesOnInsufficientHistory() {
        viewModel.skipToPreviousTrack()
        waitForQueueFlush()

        let isHistoryEmpty = viewModel.tracksPlayed.isEmpty

        XCTAssertTrue(isHistoryEmpty)
        XCTAssertEqual(mockMusicService.playCallCount, 0)
    }

    func testPlayedTrackIdsResetWhenPlaylistWraps() {
        viewModel.startRun()
        waitForQueueFlush()

        viewModel.skipToNextTrack(approximateHeartRate: 200)
        waitForQueueFlush()
        viewModel.skipToNextTrack(approximateHeartRate: 50)
        waitForQueueFlush()

        let playedIdsCount = viewModel.playedTrackIdsSnapshot.count
        let tracksPlayedCount = viewModel.tracksPlayed.count

        XCTAssertLessThanOrEqual(playedIdsCount, tracksPlayedCount)
    }

    func testStateSynchronizationWhenGoingBack() {
        viewModel.startRun()
        waitForQueueFlush()
        viewModel.skipToNextTrack()
        waitForQueueFlush()

        viewModel.skipToPreviousTrack()
        waitForQueueFlush()

        let currentTrackId2 = viewModel.currentTrack?.id
        let lastPlayedId2 = viewModel.tracksPlayed.last?.id
        let containsTrackA = viewModel.playedTrackIdsSnapshot.contains(trackA.id)

        XCTAssertEqual(currentTrackId2, trackA.id)
        XCTAssertEqual(lastPlayedId2, trackA.id)
        XCTAssertTrue(containsTrackA)
    }

    private func waitForQueueFlush(file: StaticString = #file, line: UInt = #line) {
        let expectation = expectation(description: "waitForQueueFlush")
        viewModel.flushNavigationQueue {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }
}

