import XCTest
import Combine
@testable import PulseTempo

@MainActor
final class PlaylistSelectionViewModelTests: XCTestCase {
    private var viewModel: PlaylistSelectionViewModel!
    private var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        cancellables = []
        viewModel = PlaylistSelectionViewModel()
    }
    
    override func tearDown() {
        cancellables = nil
        viewModel = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialState() {
        XCTAssertTrue(viewModel.playlists.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.selectedPlaylistIds.isEmpty)
        XCTAssertEqual(viewModel.estimatedTrackCount, 0)
    }
    
    // MARK: - Playlist Selection Tests
    
    func testTogglePlaylistSelection_WhenNotSelected() {
        let playlistId = "playlist-1"
        
        viewModel.togglePlaylistSelection(playlistId)
        
        XCTAssertTrue(viewModel.selectedPlaylistIds.contains(playlistId))
    }
    
    func testTogglePlaylistSelection_WhenAlreadySelected() {
        let playlistId = "playlist-1"
        viewModel.selectedPlaylistIds = [playlistId]
        
        viewModel.togglePlaylistSelection(playlistId)
        
        XCTAssertFalse(viewModel.selectedPlaylistIds.contains(playlistId))
    }
    
    func testIsPlaylistSelected_ReturnsTrueWhenSelected() {
        let playlistId = "playlist-1"
        viewModel.selectedPlaylistIds = [playlistId, "playlist-2"]
        
        XCTAssertTrue(viewModel.isPlaylistSelected(playlistId))
    }
    
    func testIsPlaylistSelected_ReturnsFalseWhenNotSelected() {
        let playlistId = "playlist-1"
        viewModel.selectedPlaylistIds = ["playlist-2"]
        
        XCTAssertFalse(viewModel.isPlaylistSelected(playlistId))
    }
    
    // MARK: - Error Handling Tests
    
    func testGetSelectedTracks_NoPlaylistsSelected_ReturnsError() {
        let expectation = expectation(description: "no playlists error")
        
        viewModel.getSelectedTracks { result in
            switch result {
            case .success:
                XCTFail("Should have returned error")
            case .failure(let error):
                if let playlistError = error as? PlaylistSelectionError {
                    XCTAssertEqual(playlistError, .noPlaylistsSelected)
                } else {
                    XCTFail("Wrong error type")
                }
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Multiple Selections Tests
    
    func testMultiplePlaylistSelections() {
        viewModel.togglePlaylistSelection("p1")
        viewModel.togglePlaylistSelection("p2")
        viewModel.togglePlaylistSelection("p3")
        
        XCTAssertEqual(viewModel.selectedPlaylistIds.count, 3)
        XCTAssertTrue(viewModel.selectedPlaylistIds.contains("p1"))
        XCTAssertTrue(viewModel.selectedPlaylistIds.contains("p2"))
        XCTAssertTrue(viewModel.selectedPlaylistIds.contains("p3"))
    }
    
    func testSelectAndDeselectPlaylist() {
        // Select
        viewModel.togglePlaylistSelection("p1")
        XCTAssertTrue(viewModel.isPlaylistSelected("p1"))
        XCTAssertEqual(viewModel.selectedPlaylistIds.count, 1)
        
        // Deselect
        viewModel.togglePlaylistSelection("p1")
        XCTAssertFalse(viewModel.isPlaylistSelected("p1"))
        XCTAssertTrue(viewModel.selectedPlaylistIds.isEmpty)
    }
    
    // MARK: - Error Message Tests
    
    func testPlaylistSelectionError_LocalizedDescription() {
        let noPlaylistsError = PlaylistSelectionError.noPlaylistsSelected
        let noTracksError = PlaylistSelectionError.noTracksFound
        
        XCTAssertEqual(noPlaylistsError.localizedDescription, "Please select at least one playlist")
        XCTAssertEqual(noTracksError.localizedDescription, "No tracks found in selected playlists")
    }
}
