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

    private let playbackStateSubject = CurrentValueSubject<PlaybackState, Never>(.stopped)
    private let currentTrackSubject = CurrentValueSubject<Track?, Never>(nil)
    private let errorSubject = CurrentValueSubject<Error?, Never>(nil)

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
        play(track: track) { _ in }
    }

    func replaceNext(track: Track) {
        // Mock implementation - same as playNext for testing purposes
        play(track: track) { _ in }
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

    var fetchUserPlaylistsHandler: ((@escaping (Result<[MusicPlaylist], Error>) -> Void) -> Void)?
    func fetchUserPlaylists(completion: @escaping (Result<[MusicPlaylist], Error>) -> Void) {
        if let fetchUserPlaylistsHandler {
            fetchUserPlaylistsHandler(completion)
        } else {
            completion(.success([]))
        }
    }

    var fetchTracksHandler: ((String, @escaping (Result<[Track], Error>) -> Void) -> Void)?
    func fetchTracksFromPlaylist(playlistId: String, completion: @escaping (Result<[Track], Error>) -> Void) {
        if let fetchTracksHandler {
            fetchTracksHandler(playlistId, completion)
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
