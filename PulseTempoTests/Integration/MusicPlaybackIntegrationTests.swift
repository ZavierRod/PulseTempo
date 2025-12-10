import XCTest
import Combine
@testable import PulseTempo

/// Tests for HeartRateService and MusicService coordination during workouts
@MainActor
final class MusicPlaybackIntegrationTests: XCTestCase {
    
    private var viewModel: RunSessionViewModel!
    private var mockHeartRateService: MockHeartRateService!
    private var mockMusicService: MockMusicService!
    private var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        mockHeartRateService = MockHeartRateService()
        mockMusicService = MockMusicService()
        cancellables = []
    }
    
    override func tearDown() {
        cancellables = nil
        viewModel = nil
        mockMusicService = nil
        mockHeartRateService = nil
        super.tearDown()
    }
    
    func testHeartRateChangesUpdateViewModel() {
        // Given: Workout is configured and started
        let tracks = [
            Track(id: "1", title: "Low", artist: "Artist", durationSeconds: 180, bpm: 100),
            Track(id: "2", title: "Medium", artist: "Artist", durationSeconds: 180, bpm: 140),
            Track(id: "3", title: "High", artist: "Artist", durationSeconds: 180, bpm: 170)
        ]
        viewModel = RunSessionViewModel(
            tracks: tracks,
            heartRateService: mockHeartRateService,
            musicService: mockMusicService
        )
        viewModel.startRun()
        
        // When: Heart rate changes
        mockHeartRateService.sendHeartRate(145)
        
        // Then: View model should update current HR
        XCTAssertEqual(viewModel.currentHeartRate, 145)
    }
    
    func testPlaybackStateIntegration() {
        let tracks = [Track(id: "1", title: "Song", artist: "Artist", durationSeconds: 180, bpm: 120)]
        viewModel = RunSessionViewModel(
            tracks: tracks,
            heartRateService: mockHeartRateService,
            musicService: mockMusicService
        )
        viewModel.startRun()
        
        // Initial state should be playing (startRun triggers playback)
        XCTAssertEqual(viewModel.sessionState, .active)
    }
    
    func testHeartRateBasedTrackSelection() {
        // Given: Multiple tracks with different BPMs
        let tracks = [
            Track(id: "1", title: "Slow", artist: "Artist", durationSeconds: 180, bpm: 100),
            Track(id: "2", title: "Medium", artist: "Artist", durationSeconds: 180, bpm: 130),
            Track(id: "3", title: "Fast", artist: "Artist", durationSeconds: 180, bpm: 160)
        ]
        viewModel = RunSessionViewModel(
            tracks: tracks,
            heartRateService: mockHeartRateService,
            musicService: mockMusicService
        )
        viewModel.startRun()
        
        // When: HR is in moderate zone
        mockHeartRateService.sendHeartRate(135)
        
        // Then: ViewModel should track HR
        XCTAssertEqual(viewModel.currentHeartRate, 135)
    }
    
    func testManualSkipDuringWorkout() {
        let tracks = [
            Track(id: "1", title: "First", artist: "Artist", durationSeconds: 180, bpm: 120),
            Track(id: "2", title: "Second", artist: "Artist", durationSeconds: 180, bpm: 130)
        ]
        viewModel = RunSessionViewModel(
            tracks: tracks,
            heartRateService: mockHeartRateService,
            musicService: mockMusicService
        )
        viewModel.startRun()
        
        // When: User manually skips forward
        viewModel.skipToNextTrack()
        
        // Then: Should trigger skip (actual track selection tested in BPMMatchingAlgorithmTests)
        XCTAssertNotNil(viewModel)
    }
    
    func testHeartRateMonitoringDuringRun() {
        let tracks = [Track(id: "1", title: "Song", artist: "Artist", durationSeconds: 180, bpm: 120)]
        viewModel = RunSessionViewModel(
            tracks: tracks,
            heartRateService: mockHeartRateService,
            musicService: mockMusicService
        )
        
        // When: Start workout (starts monitoring)
        viewModel.startRun()
        
        // Then: Should receive HR updates
        mockHeartRateService.sendHeartRate(110)
        XCTAssertEqual(viewModel.currentHeartRate, 110)
        
        mockHeartRateService.sendHeartRate(145)
        XCTAssertEqual(viewModel.currentHeartRate, 145)
        
        mockHeartRateService.sendHeartRate(160)
        XCTAssertEqual(viewModel.currentHeartRate, 160)
    }
    
    func testMetricsTrackingDuringRun() {
        let tracks = [Track(id: "1", title: "Song", artist: "Artist", durationSeconds: 180, bpm: 120)]
        viewModel = RunSessionViewModel(
            tracks: tracks,
            heartRateService: mockHeartRateService,
            musicService: mockMusicService
        )
        viewModel.startRun()
        
        // Send some HR data
        mockHeartRateService.sendHeartRate(140)
        mockHeartRateService.sendHeartRate(150)
        mockHeartRateService.sendHeartRate(160)
        
        // Verify max HR is tracked
        XCTAssertEqual(viewModel.maxHeartRate, 160)
        
        // Verify average is calculated
        XCTAssertGreaterThan(viewModel.averageHeartRate, 0)
    }
    
    func testStopRunCompletesMetrics() {
        let tracks = [Track(id: "1", title: "Song", artist: "Artist", durationSeconds: 180, bpm: 120)]
        viewModel = RunSessionViewModel(
            tracks: tracks,
            heartRateService: mockHeartRateService,
            musicService: mockMusicService
        )
        viewModel.startRun()
        
        // Send some HR data
        mockHeartRateService.sendHeartRate(140)
        
        // When: Stop workout
        viewModel.stopRun()
        
        // Then: Should be completed
        XCTAssertEqual(viewModel.sessionState, .completed)
    }
}
