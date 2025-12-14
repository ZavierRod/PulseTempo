from typing import Any, List
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from datetime import datetime
from uuid import UUID
from app import deps
from app.models.run import Run, RunTrack
from app.models.user import User

router = APIRouter()

class RunTrackCreate(BaseModel):
    track_id: str
    played_at: datetime
    heart_rate_at_start: int | None = None

class RunCreate(BaseModel):
    start_time: datetime
    end_time: datetime
    avg_heart_rate: int | None = None
    total_distance: float | None = None
    tracks: List[RunTrackCreate] = []

class RunResponse(BaseModel):
    id: UUID
    start_time: datetime
    end_time: datetime
    avg_heart_rate: int | None
    total_distance: float | None

@router.post("/", response_model=RunResponse)
def create_run(
    run_in: RunCreate,
    db: Session = Depends(deps.get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """
    Save a completed run session.
    """
    run = Run(
        user_id=current_user.id,
        start_time=run_in.start_time,
        end_time=run_in.end_time,
        avg_heart_rate=run_in.avg_heart_rate,
        total_distance=run_in.total_distance
    )
    db.add(run)
    db.flush() # Get run.id
    
    for track_in in run_in.tracks:
        run_track = RunTrack(
            run_id=run.id,
            track_id=track_in.track_id,
            played_at=track_in.played_at,
            heart_rate_at_start=track_in.heart_rate_at_start
        )
        db.add(run_track)
    
    db.commit()
    db.refresh(run)
    return run

@router.get("/", response_model=List[RunResponse])
def get_runs(
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(deps.get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """
    Get run history for current user.
    """
    runs = db.query(Run).filter(Run.user_id == current_user.id).offset(skip).limit(limit).all()
    return runs
