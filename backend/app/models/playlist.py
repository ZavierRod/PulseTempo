from sqlalchemy import Column, String, ForeignKey, Table
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from app.db.base_class import Base

# Association table for Playlist-Track many-to-many relationship
playlist_track = Table(
    "playlist_track",
    Base.metadata,
    Column("playlist_id", String, ForeignKey("playlists.id"), primary_key=True),
    Column("track_id", String, ForeignKey("tracks.id"), primary_key=True),
)

class Playlist(Base):
    __tablename__ = "playlists"

    id = Column(String, primary_key=True)  # Apple Music Playlist ID
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    name = Column(String, nullable=False)

    # Relationships
    user = relationship("User", backref="playlists")
    tracks = relationship("Track", secondary=playlist_track, backref="playlists")
