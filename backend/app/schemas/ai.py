from typing import List, Optional
from pydantic import BaseModel, Field


class DJScriptRequest(BaseModel):
    runner_name: str = Field(..., min_length=1, max_length=120)
    current_heart_rate: int = Field(..., ge=0, le=260)
    elapsed_time_seconds: int = Field(..., ge=0, le=86400)
    current_song_title: str = Field(..., min_length=1, max_length=300)
    current_song_artist: str = Field(..., min_length=1, max_length=300)
    current_song_elapsed_seconds: int = Field(..., ge=0, le=7200)
    current_song_duration_seconds: int = Field(..., ge=0, le=7200)
    next_song_title: Optional[str] = Field(default=None, max_length=300)
    next_song_artist: Optional[str] = Field(default=None, max_length=300)
    trigger_reason: str = Field(..., min_length=1, max_length=80)
    recent_scripts: List[str] = Field(default_factory=list, max_length=10)


class DJScriptResponse(BaseModel):
    script: str
