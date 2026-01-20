from typing import Any, List
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError
from pydantic import BaseModel
from app import deps
from app.models.track import Track
from app.models.user import User
from app.services.bpm_analyzer import BPMAnalyzer

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


class TrackAnalyzeRequest(BaseModel):
    apple_music_id: str
    preview_url: str


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


class AnalyzeResponse(BaseModel):
    apple_music_id: str
    bpm: float
    confidence: float


@router.post("/analyze", response_model=AnalyzeResponse)
def analyze_track(
    request: TrackAnalyzeRequest,
    db: Session = Depends(deps.get_db),
    # TODO: Re-enable auth for production
    # current_user: User = Depends(deps.get_current_user),
) -> Any:
    """
    Analyze a track's BPM using its preview URL.
    Auto-creates track record if it doesn't exist.
    """
    # Check if track exists and already has high-confidence BPM
    track = db.query(Track).filter(Track.id == request.apple_music_id).first()
    if track and track.bpm and track.confidence == 1.0:
        return AnalyzeResponse(
            apple_music_id=track.id,
            bpm=track.bpm,
            confidence=track.confidence
        )

    # Analyze the preview URL
    try:
        bpm = BPMAnalyzer.analyze_url(request.preview_url)
    except HTTPException as e:
        raise e
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

    # Create or update track in DB (handle race condition)
    if not track:
        track = Track(
            id=request.apple_music_id,
            title="Unknown",  # Will be updated later if needed
            artist="Unknown",
            bpm=bpm,
            confidence=1.0,
            source="librosa_analysis"
        )
        db.add(track)
        try:
            db.commit()
        except IntegrityError:
            # Race condition: another request already inserted this track
            db.rollback()
            track = db.query(Track).filter(
                Track.id == request.apple_music_id).first()
            if track:
                track.bpm = bpm
                track.confidence = 1.0
                track.source = "librosa_analysis"
                db.commit()
    else:
        track.bpm = bpm
        track.confidence = 1.0
        track.source = "librosa_analysis"
        db.commit()

    return AnalyzeResponse(
        apple_music_id=request.apple_music_id,
        bpm=bpm,
        confidence=1.0
    )
