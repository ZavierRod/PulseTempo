from typing import Optional
from pydantic import BaseModel
from uuid import UUID
from datetime import datetime

class UserBase(BaseModel):
    email: Optional[str] = None

class UserCreate(UserBase):
    apple_user_id: str

class UserUpdate(UserBase):
    pass

class UserInDBBase(UserBase):
    id: UUID
    apple_user_id: str
    created_at: datetime

    class Config:
        from_attributes = True

class User(UserInDBBase):
    pass
