import uuid
from sqlalchemy import Column, String, DateTime
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func
from app.db.base_class import Base

class User(Base):
    __tablename__ = "users"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    # Apple Sign In (nullable for email-only users)
    apple_user_id = Column(String, unique=True, index=True, nullable=True)
    # Email authentication
    email = Column(String, unique=True, index=True, nullable=True)
    hashed_password = Column(String, nullable=True)
    # Profile info
    username = Column(String, unique=True, index=True, nullable=True)
    first_name = Column(String, nullable=True)
    last_name = Column(String, nullable=True)
    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now())
