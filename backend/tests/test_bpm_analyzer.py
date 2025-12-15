import sys
import pytest
from unittest.mock import MagicMock, patch

# Mock dependencies before import to avoid installation requirement
mock_librosa = MagicMock()
sys.modules["librosa"] = mock_librosa

mock_numpy = MagicMock()
mock_numpy.ndarray = list # Make ndarray a valid type for isinstance
sys.modules["numpy"] = mock_numpy

mock_requests = MagicMock()
mock_requests.RequestException = Exception # Make RequestException a valid exception class
sys.modules["requests"] = mock_requests

from fastapi.testclient import TestClient
from app.main import app
from app.services.bpm_analyzer import BPMAnalyzer

client = TestClient(app)

# Mock data
MOCK_URL = "http://example.com/preview.m4a"
MOCK_BPM = 120.5

@pytest.fixture
def mock_librosa():
    with patch("app.services.bpm_analyzer.librosa") as mock:
        # Mock load to return dummy audio data
        mock.load.return_value = (MagicMock(), 22050)
        # Mock beat_track to return our BPM
        mock.beat.beat_track.return_value = (MOCK_BPM, MagicMock())
        # Mock onset_strength
        mock.onset.onset_strength.return_value = MagicMock()
        yield mock

@pytest.fixture
def mock_requests():
    with patch("app.services.bpm_analyzer.requests") as mock:
        mock_response = MagicMock()
        mock_response.iter_content.return_value = [b"chunk1", b"chunk2"]
        mock.get.return_value = mock_response
        yield mock

def test_bpm_analyzer_service(mock_librosa, mock_requests):
    bpm = BPMAnalyzer.analyze_url(MOCK_URL)
    assert bpm == MOCK_BPM
    mock_requests.get.assert_called_once_with(MOCK_URL, stream=True)
    mock_librosa.load.assert_called_once()
    mock_librosa.beat.beat_track.assert_called_once()

# We need to mock the DB dependency or use a test DB for the API test
# For simplicity, we'll just mock the BPMAnalyzer.analyze_url call in the API test
# and assume the DB part works (or use the existing DB setup if available)

from app import deps
from app.models.track import Track

@pytest.fixture
def mock_db():
    session = MagicMock()
    return session

@patch("app.routers.tracks.BPMAnalyzer.analyze_url")
def test_analyze_endpoint(mock_analyze, mock_db):
    # Override dependencies
    app.dependency_overrides[deps.get_db] = lambda: mock_db
    app.dependency_overrides[deps.get_current_user] = lambda: MagicMock()
    
    # Mock analyze return value
    mock_analyze.return_value = MOCK_BPM
    
    # Mock DB query to return a track
    mock_track = MagicMock(spec=Track)
    mock_track.id = "test_track_123"
    mock_track.title = "Test Song"
    mock_track.artist = "Test Artist"
    mock_track.bpm = None
    mock_track.confidence = None
    
    # Setup query chain explicitly
    # db.query(Track) -> query_obj
    # query_obj.filter(...) -> filter_obj
    # filter_obj.first() -> mock_track
    
    filter_obj = MagicMock()
    filter_obj.first.return_value = mock_track
    
    query_obj = MagicMock()
    query_obj.filter.return_value = filter_obj
    
    mock_db.query.return_value = query_obj
    
    # Call analyze endpoint
    response = client.post("/api/tracks/analyze", json={
        "apple_music_id": "test_track_123",
        "preview_url": MOCK_URL
    })
    
    # Clean up overrides
    app.dependency_overrides = {}
    
    assert response.status_code == 200
    data = response.json()
    
    # Verify BPM was updated on the track object
    assert mock_track.bpm == MOCK_BPM
    assert mock_track.confidence == 1.0
    assert mock_track.source == "librosa_analysis"
    
    # Verify DB commit was called
    mock_db.commit.assert_called_once()
    mock_db.refresh.assert_called_once_with(mock_track)

