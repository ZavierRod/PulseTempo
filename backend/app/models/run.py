import uuid
from sqlalchemy import Column, DateTime, Integer, Float, ForeignKey, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from app.db.base_class import Base

class Run(Base):
    __tablename__ = "runs"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    start_time = Column(DateTime(timezone=True), nullable=False)
    end_time = Column(DateTime(timezone=True), nullable=False)
    avg_heart_rate = Column(Integer, nullable=True)
    total_distance = Column(Float, nullable=True)  # in meters

    # Relationships
    user = relationship("User", backref="runs")
    tracks = relationship("RunTrack", back_populates="run")

class RunTrack(Base):
    __tablename__ = "run_tracks"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    run_id = Column(UUID(as_uuid=True), ForeignKey("runs.id"), nullable=False)
    track_id = Column(String, ForeignKey("tracks.id"), nullable=False)
    played_at = Column(DateTime(timezone=True), nullable=False)
    heart_rate_at_start = Column(Integer, nullable=True)
    
    # Relationships
    run = relationship("Run", back_populates="tracks")
    track = relationship("Track")
