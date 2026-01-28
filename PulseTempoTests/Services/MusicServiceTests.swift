import XCTest
import MusicKit
import Combine
@testable import PulseTempo

@MainActor
final class MusicServiceTests: XCTestCase {
    private var cancellables: Set<AnyCancellable> = []
    private var musicKitManager: MockMusicKitManager!
    private var service: TestMusicService!

    override func setUp() {
        super.setUp()
        musicKitManager = MockMusicKitManager()
        service = TestMusicService(musicKitManager: musicKitManager)
    }

    override func tearDown() {
        cancellables = []
        service = nil
        musicKitManager = nil
        super.tearDown()
    }

    func testPlayTrack_Success() {
        let track = PulseTempo.Track(id: "1", title: "Song", artist: "Artist", durationSeconds: 200, bpm: 120)
        let expectation = expectation(description: "play track")

        service.play(track: track) { result in
            XCTAssertTrue(result.isSuccess)
            XCTAssertEqual(self.service.currentTrack, track)
            XCTAssertEqual(self.service.playbackState, .playing)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testPause_StopsPlayback() {
        service.playbackState = .playing
        service.pause()
        XCTAssertEqual(service.playbackState, .paused)
    }

    func testResume_StartsPlayback() {
        service.playbackState = .paused
        service.resume()
        XCTAssertEqual(service.playbackState, .playing)
    }

    func testStop_ClearsState() {
        service.currentTrack = PulseTempo.Track(id: "1", title: "Song", artist: "Artist", durationSeconds: 200, bpm: 120)
        service.playbackState = .playing
        service.stop()

        XCTAssertEqual(service.playbackState, .stopped)
        XCTAssertNil(service.currentTrack)
        XCTAssertEqual(service.currentPlaybackTime, 0)
    }

    func testPlayNext_AddsToQueue() {
        let current = PulseTempo.Track(id: "1", title: "Song", artist: "Artist", durationSeconds: 200, bpm: 120)
        let next = PulseTempo.Track(id: "2", title: "Next", artist: "Artist", durationSeconds: 180, bpm: 125)
        service.currentTrack = current
        service.trackQueue = [current]

        service.playNext(track: next)
        XCTAssertEqual(service.trackQueue, [current, next])
    }

    func testReplaceNext_MaintainsQueueSizeOne() {
        let current = PulseTempo.Track(id: "1", title: "Song", artist: "Artist", durationSeconds: 200, bpm: 120)
        let first = PulseTempo.Track(id: "2", title: "Next", artist: "Artist", durationSeconds: 180, bpm: 125)
        let second = PulseTempo.Track(id: "3", title: "New", artist: "Artist", durationSeconds: 210, bpm: 128)
        service.currentTrack = current
        service.trackQueue = [current]

        service.replaceNext(track: first)
        XCTAssertEqual(service.trackQueue, [current, first])

        service.replaceNext(track: second)
        XCTAssertEqual(service.trackQueue, [current, second])
    }

    func testFetchUserPlaylists_Success() {
        let expectation = expectation(description: "playlists")
        service.playlistsToReturn = [.init(id: "1", name: "P1", trackCount: 1, artwork: nil)]

        service.fetchUserPlaylists { result in
            XCTAssertTrue(result.isSuccess)
            XCTAssertEqual(self.service.userPlaylists, self.service.playlistsToReturn)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testFetchTracksFromPlaylist_Success() {
        let expectation = expectation(description: "tracks")
        let tracks = [PulseTempo.Track(id: "t1", title: "Song", artist: "Artist", durationSeconds: 200, bpm: 120)]
        service.tracksToReturn = tracks

        service.fetchTracksFromPlaylist(playlistId: "id", triggerBPMAnalysis: false) { result in
            XCTAssertTrue(result.isSuccess)
            XCTAssertEqual(tracks, self.service.tracksToReturn)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testPlaybackStatePublisher() {
        let expectation = expectation(description: "state publish")
        var received: [PlaybackState] = []

        service.playbackStatePublisher
            .sink { state in
                received.append(state)
                if received.count == 2 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        service.playbackState = .playing
        service.playbackState = .paused

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(received.suffix(2), [.playing, .paused])
    }

    func testCurrentTrackPublisher() {
        let expectation = expectation(description: "track publish")
        var received: [PulseTempo.Track?] = []
        let track = PulseTempo.Track(id: "1", title: "Song", artist: "Artist", durationSeconds: 200, bpm: 120)

        service.currentTrackPublisher
            .sink { value in
                received.append(value)
                if received.contains(where: { $0 == track }) {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        service.currentTrack = track

        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(received.contains(track))
    }
}

private extension Result {
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}

final class TestMusicService: MusicService {
    var playlistsToReturn: [MusicPlaylist] = []
    var tracksToReturn: [PulseTempo.Track] = []

    init(musicKitManager: MusicKitManager) {
        super.init(musicKitManager: musicKitManager, player: .shared)
    }

    override func play(track: PulseTempo.Track, completion: @escaping (Result<Void, Error>) -> Void) {
        currentTrack = track
        playbackState = .playing
        completion(.success(()))
    }

    override func pause() {
        playbackState = .paused
    }

    override func resume() {
        playbackState = .playing
    }

    override func stop() {
        playbackState = .stopped
        currentTrack = nil
        currentPlaybackTime = 0
    }

    override func playNext(track: PulseTempo.Track) {
        if let currentIndex = trackQueue.firstIndex(where: { $0.id == currentTrack?.id }) {
            trackQueue.insert(track, at: currentIndex + 1)
        } else {
            trackQueue.append(track)
        }
    }

    override func replaceNext(track: PulseTempo.Track) {
        if let current = currentTrack {
            trackQueue = [current, track]
        } else {
            trackQueue = [track]
        }
    }

    override func fetchUserPlaylists(completion: @escaping (Result<[MusicPlaylist], Error>) -> Void) {
        userPlaylists = playlistsToReturn
        completion(.success(playlistsToReturn))
    }

    override func fetchTracksFromPlaylist(playlistId: String, triggerBPMAnalysis: Bool = false, completion: @escaping (Result<[PulseTempo.Track], Error>) -> Void) {
        completion(.success(tracksToReturn))
    }
}

final class MockMusicKitManager: MusicKitManager {
    var requestedAuthorization = false
    var authorizedStatus: MusicAuthorization.Status = .authorized
    var subscriptionActive = true

    override var authorizationStatus: MusicAuthorization.Status {
        authorizedStatus
    }

    override var isAuthorized: Bool {
        authorizationStatus == .authorized
    }

    override func requestAuthorization(completion: @escaping (MusicAuthorization.Status) -> Void) {
        requestedAuthorization = true
        completion(authorizedStatus)
    }

    override func checkSubscriptionStatus() async -> Bool {
        subscriptionActive
    }
}
