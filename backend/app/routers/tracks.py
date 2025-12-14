from typing import Any, List
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from app import deps
from app.models.track import Track
from app.models.user import User

router = APIRouter()

class TrackCreate(BaseModel):
    id: str
    title: str
    artist: str
    bpm: float | None = None
    confidence: float | None = None

class TrackResponse(BaseModel):
    id: str
    title: str
    artist: str
    bpm: float | None
    confidence: float | None

@router.post("/register", response_model=List[TrackResponse])
def register_tracks(
    tracks: List[TrackCreate],
    db: Session = Depends(deps.get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """
    Register tracks from Apple Music library.
    If track exists, update BPM if provided and confidence is higher.
    """
    results = []
    for track_in in tracks:
        track = db.query(Track).filter(Track.id == track_in.id).first()
        if not track:
            track = Track(
                id=track_in.id,
                title=track_in.title,
                artist=track_in.artist,
                bpm=track_in.bpm,
                confidence=track_in.confidence,
                source="apple_music"
            )
            db.add(track)
        else:
            # Update logic could go here (e.g. if new BPM has higher confidence)
            if track_in.bpm and (track.bpm is None or (track_in.confidence or 0) > (track.confidence or 0)):
                track.bpm = track_in.bpm
                track.confidence = track_in.confidence
        
        results.append(track)
    
    db.commit()
    return results

@router.get("/{track_id}", response_model=TrackResponse)
def get_track(
    track_id: str,
    db: Session = Depends(deps.get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """
    Get track details including BPM.
    """
    track = db.query(Track).filter(Track.id == track_id).first()
    if not track:
        raise HTTPException(status_code=404, detail="Track not found")
    return track
