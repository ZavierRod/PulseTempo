import XCTest
import Combine
@testable import PulseTempo

/// Tests for workout initialization and flow with playlist integration
@MainActor
final class WorkoutFlowTests: XCTestCase {
    
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
    
    func testWorkoutInitializationWithTracks() {
        // Given: Tracks from selected playlists
        let tracks = [
            Track(id: "1", title: "Warm Up", artist: "Artist", durationSeconds: 180, bpm: 110),
            Track(id: "2", title: "Steady Run", artist: "Artist", durationSeconds: 240, bpm: 140),
            Track(id: "3", title: "Cooldown", artist: "Artist", durationSeconds: 200, bpm: 100)
        ]
        
        // When: Initialize workout with tracks
        viewModel = RunSessionViewModel(
            tracks: tracks,
            heartRateService: mockHeartRateService,
            musicService: mockMusicService
        )
        
        // Then: View model should be initialized
        XCTAssertNotNil(viewModel)
        XCTAssertEqual(viewModel.sessionState, .notStarted)
    }
    
    func testWorkoutStateTransitions() {
        viewModel = RunSessionViewModel(
            tracks: [Track(id: "1", title: "Song", artist: "Artist", durationSeconds: 180, bpm: 120)],
            heartRateService: mockHeartRateService,
            musicService: mockMusicService
        )
        
        // Initial state
        XCTAssertEqual(viewModel.sessionState, .notStarted)
        
        // Start workout
        viewModel.startRun()
        XCTAssertEqual(viewModel.sessionState, .active)
        
        // Pause workout
        viewModel.pauseRun()
        XCTAssertEqual(viewModel.sessionState, .paused)
        
        // Resume workout
        viewModel.resumeRun()
        XCTAssertEqual(viewModel.sessionState, .active)
        
        // End workout
        viewModel.stopRun()
        XCTAssertEqual(viewModel.sessionState, .completed)
    }
    
    func testWorkoutWithEmptyTracks() {
        // When: Initialize with empty track list
        viewModel = RunSessionViewModel(
            tracks: [],
            heartRateService: mockHeartRateService,
            musicService: mockMusicService
        )
        
        // Then: Should use fake/demo tracks instead
        XCTAssertNotNil(viewModel)
        XCTAssertEqual(viewModel.sessionState, .notStarted)
    }
    
   func testWorkoutPauseResumeCycle() {
        viewModel = RunSessionViewModel(
            tracks: [Track(id: "1", title: "Song", artist: "Artist", durationSeconds: 180, bpm: 120)],
            heartRateService: mockHeartRateService,
            musicService: mockMusicService
        )
        viewModel.startRun()
        
        // Multiple pause/resume cycles
        for _ in 0..<3 {
            viewModel.pauseRun()
            XCTAssertEqual(viewModel.sessionState, .paused)
            
            viewModel.resumeRun()
            XCTAssertEqual(viewModel.sessionState, .active)
        }
    }
    
    func testWorkoutStopFromActiveState() {
        viewModel = RunSessionViewModel(
            tracks: [Track(id: "1", title: "Song", artist: "Artist", durationSeconds: 180, bpm: 120)],
            heartRateService: mockHeartRateService,
            musicService: mockMusicService
        )
        viewModel.startRun()
        
        XCTAssertEqual(viewModel.sessionState, .active)
        
        viewModel.stopRun()
        
        XCTAssertEqual(viewModel.sessionState, .completed)
    }
    
    func testWorkoutStopFromPausedState() {
        viewModel = RunSessionViewModel(
            tracks: [Track(id: "1", title: "Song", artist: "Artist", durationSeconds: 180, bpm: 120)],
            heartRateService: mockHeartRateService,
            musicService: mockMusicService
        )
        viewModel.startRun()
        viewModel.pauseRun()
        
        XCTAssertEqual(viewModel.sessionState, .paused)
        
        viewModel.stopRun()
        
        XCTAssertEqual(viewModel.sessionState, .completed)
    }
    
    func testWorkoutWithMultipleTracks() {
        let tracks = (1...10).map { i in
            Track(id: "\(i)", title: "Song \(i)", artist: "Artist", durationSeconds: 180, bpm: 120 + i)
        }
        
        viewModel = RunSessionViewModel(
            tracks: tracks,
            heartRateService: mockHeartRateService,
            musicService: mockMusicService
        )
        
        XCTAssertNotNil(viewModel)
        XCTAssertEqual(viewModel.sessionState, .notStarted)
    }
    
    func testTogglePlayPause() {
        viewModel =  RunSessionViewModel(
            tracks: [Track(id: "1", title: "Song", artist: "Artist", durationSeconds: 180, bpm: 120)],
            heartRateService: mockHeartRateService,
            musicService: mockMusicService
        )
        
        viewModel.startRun()
        XCTAssertEqual(viewModel.sessionState, .active)
        
        // Toggle should pause
        viewModel.togglePlayPause()
        XCTAssertEqual(viewModel.sessionState, .paused)
        
        // Toggle should resume
        viewModel.togglePlayPause()
        XCTAssertEqual(viewModel.sessionState, .active)
    }
}
