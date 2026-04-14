from types import SimpleNamespace
from unittest.mock import AsyncMock, patch

from fastapi.testclient import TestClient

from app import deps
from app.main import app

client = TestClient(app)


@patch("app.routers.ai.OpenAIDJService.generate_script", new_callable=AsyncMock)
def test_generate_dj_script(mock_generate_script):
    app.dependency_overrides[deps.get_current_user] = lambda: SimpleNamespace(id="user-1")
    mock_generate_script.return_value = "Lock in, you're flying."

    response = client.post(
        "/api/ai/dj-script",
        json={
            "runner_name": "Zavier",
            "current_heart_rate": 155,
            "elapsed_time_seconds": 900,
            "current_song_title": "Wicked Freestyle",
            "current_song_artist": "Nardo Wick",
            "current_song_elapsed_seconds": 120,
            "current_song_duration_seconds": 210,
            "next_song_title": None,
            "next_song_artist": None,
            "trigger_reason": "time_checkin",
            "recent_scripts": ["Stay smooth."],
        },
    )

    app.dependency_overrides = {}

    assert response.status_code == 200
    assert response.json() == {"script": "Lock in, you're flying."}
    mock_generate_script.assert_awaited_once()
