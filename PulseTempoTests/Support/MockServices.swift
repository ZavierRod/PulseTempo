import Foundation
import Combine
@testable import PulseTempo

final class MockHeartRateService: HeartRateServiceProtocol {
    var currentHeartRatePublisher: AnyPublisher<Int, Never> { currentHeartRateSubject.eraseToAnyPublisher() }
    var errorPublisher: AnyPublisher<Error?, Never> { errorSubject.eraseToAnyPublisher() }

    private let currentHeartRateSubject = CurrentValueSubject<Int, Never>(0)
    private let errorSubject = CurrentValueSubject<Error?, Never>(nil)

    func sendHeartRate(_ value: Int) {
        currentHeartRateSubject.send(value)
    }

    func sendError(_ error: Error) {
        errorSubject.send(error)
    }

    func startMonitoring(useDemoMode: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }

    func stopMonitoring() {}
}

final class MockMusicService: MusicServiceProtocol {
    var playbackStatePublisher: AnyPublisher<PlaybackState, Never> { playbackStateSubject.eraseToAnyPublisher() }
    var currentTrackPublisher: AnyPublisher<Track?, Never> { currentTrackSubject.eraseToAnyPublisher() }
    var errorPublisher: AnyPublisher<Error?, Never> { errorSubject.eraseToAnyPublisher() }
    var currentPlaybackTimePublisher: AnyPublisher<TimeInterval, Never> { currentPlaybackTimeSubject.eraseToAnyPublisher() }
    var trackUpdatedPublisher: AnyPublisher<Track, Never> { trackUpdatedSubject.eraseToAnyPublisher() }
    var playbackInterruptedPublisher: AnyPublisher<Bool, Never> { playbackInterruptedSubject.eraseToAnyPublisher() }

    private let playbackStateSubject = CurrentValueSubject<PlaybackState, Never>(.stopped)
    private let currentTrackSubject = CurrentValueSubject<Track?, Never>(nil)
    private let errorSubject = CurrentValueSubject<Error?, Never>(nil)
    private let currentPlaybackTimeSubject = CurrentValueSubject<TimeInterval, Never>(0)
    private let trackUpdatedSubject = PassthroughSubject<Track, Never>()
    private let playbackInterruptedSubject = CurrentValueSubject<Bool, Never>(false)

    var playedTracks: [Track] = []
    var playCallCount = 0
    var playQueueCallCount = 0

    func play(track: Track, completion: @escaping (Result<Void, Error>) -> Void) {
        playCallCount += 1
        playedTracks.append(track)
        currentTrackSubject.send(track)
        playbackStateSubject.send(.playing)
        completion(.success(()))
    }

    func playQueue(tracks: [Track], startIndex: Int, completion: @escaping (Result<Void, Error>) -> Void) {
        playQueueCallCount += 1
        guard startIndex < tracks.count else {
            completion(.failure(NSError(domain: "MockMusicService", code: 1)))
            return
        }
        let track = tracks[startIndex]
        play(track: track, completion: completion)
    }

    func playNext(track: Track) {
        // Just record the track, don't play it immediately
    }

    func replaceNext(track: Track) {
        // Just record the track, don't play it immediately
    }

    func pause() {
        playbackStateSubject.send(.paused)
    }

    func resume() {
        playbackStateSubject.send(.playing)
    }

    func stop() {
        playbackStateSubject.send(.stopped)
        currentTrackSubject.send(nil)
    }

    func retryPlaybackAfterInterruption() {
        playbackInterruptedSubject.send(false)
    }

    var fetchUserPlaylistsHandler: ((@escaping (Result<[MusicPlaylist], Error>) -> Void) -> Void)?
    func fetchUserPlaylists(completion: @escaping (Result<[MusicPlaylist], Error>) -> Void) {
        if let fetchUserPlaylistsHandler {
            fetchUserPlaylistsHandler(completion)
        } else {
            completion(.success([]))
        }
    }

    var fetchTracksHandler: ((String, Bool, @escaping (Result<[Track], Error>) -> Void) -> Void)?
    func fetchTracksFromPlaylist(playlistId: String, triggerBPMAnalysis: Bool, completion: @escaping (Result<[Track], Error>) -> Void) {
        if let fetchTracksHandler {
            fetchTracksHandler(playlistId, triggerBPMAnalysis, completion)
        } else {
            completion(.success([]))
        }
    }
}

final class MockPlaylistStorageManager: PlaylistStorageManaging {
    private(set) var storedIds: [String] = []

    var hasSelectedPlaylists: Bool { !storedIds.isEmpty }

    func saveSelectedPlaylists(_ playlistIds: [String]) {
        storedIds = playlistIds
    }

    func loadSelectedPlaylists() -> [String] {
        storedIds
    }

    func clearSelectedPlaylists() {
        storedIds.removeAll()
    }
}
