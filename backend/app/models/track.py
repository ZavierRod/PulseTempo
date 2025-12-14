from sqlalchemy import Column, String, Float, Integer
from app.db.base_class import Base

class Track(Base):
    __tablename__ = "tracks"

    id = Column(String, primary_key=True)  # Apple Music ID
    title = Column(String, nullable=False)
    artist = Column(String, nullable=False)
    bpm = Column(Float, nullable=True)
    confidence = Column(Float, nullable=True)  # 0.0 to 1.0
    source = Column(String, nullable=True)     # e.g., "apple_music", "spotify_api", "analysis"
