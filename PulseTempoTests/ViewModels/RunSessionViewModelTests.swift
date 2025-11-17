import XCTest
@testable import PulseTempo

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

        XCTAssertEqual(mockMusicService.playCallCount, 2, "Initial play + next skip should trigger two play calls")
        XCTAssertEqual(viewModel.tracksPlayed.last?.id, mockMusicService.playedTracks.last?.id)
        XCTAssertTrue(viewModel.playedTrackIdsSnapshot.contains(mockMusicService.playedTracks.last!.id))
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

        XCTAssertEqual(mockMusicService.playCallCount, initialPlayCount + 1, "Debounce should block back-to-back previous calls")
        XCTAssertEqual(viewModel.currentTrack?.id, trackA.id)
        XCTAssertEqual(viewModel.tracksPlayed.last?.id, trackA.id)
    }

    func testTrackHistoryManagementPreventsCrashesOnInsufficientHistory() {
        viewModel.skipToPreviousTrack()
        waitForQueueFlush()

        XCTAssertTrue(viewModel.tracksPlayed.isEmpty)
        XCTAssertEqual(mockMusicService.playCallCount, 0)
    }

    func testPlayedTrackIdsResetWhenPlaylistWraps() {
        viewModel.startRun()
        waitForQueueFlush()

        viewModel.skipToNextTrack(approximateHeartRate: 200)
        waitForQueueFlush()
        viewModel.skipToNextTrack(approximateHeartRate: 50)
        waitForQueueFlush()

        XCTAssertLessThanOrEqual(viewModel.playedTrackIdsSnapshot.count, viewModel.tracksPlayed.count)
    }

    func testStateSynchronizationWhenGoingBack() {
        viewModel.startRun()
        waitForQueueFlush()
        viewModel.skipToNextTrack()
        waitForQueueFlush()

        viewModel.skipToPreviousTrack()
        waitForQueueFlush()

        XCTAssertEqual(viewModel.currentTrack?.id, trackA.id)
        XCTAssertEqual(viewModel.tracksPlayed.last?.id, trackA.id)
        XCTAssertTrue(viewModel.playedTrackIdsSnapshot.contains(trackA.id))
    }

    private func waitForQueueFlush(file: StaticString = #file, line: UInt = #line) {
        let expectation = expectation(description: "waitForQueueFlush")
        DispatchQueue.main.async {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }
}
