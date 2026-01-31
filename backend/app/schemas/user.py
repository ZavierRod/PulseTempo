from typing import Optional
from pydantic import BaseModel, EmailStr
from uuid import UUID
from datetime import datetime

class UserBase(BaseModel):
    email: Optional[str] = None
    first_name: Optional[str] = None
    last_name: Optional[str] = None

# For Apple Sign In
class UserCreateApple(UserBase):
    apple_user_id: str

# For Email/Password registration
class UserCreateEmail(BaseModel):
    email: EmailStr
    password: str
    first_name: Optional[str] = None
    last_name: Optional[str] = None

# For Email login
class UserLoginEmail(BaseModel):
    email: EmailStr
    password: str

# Legacy alias for backwards compatibility
UserCreate = UserCreateApple

class UserUpdate(UserBase):
    pass

class UserInDBBase(UserBase):
    id: UUID
    apple_user_id: Optional[str] = None
    created_at: datetime

    class Config:
        from_attributes = True

class User(UserInDBBase):
    pass

class UserResponse(BaseModel):
    """User info returned to client (no sensitive data)"""
    id: UUID
    email: Optional[str] = None
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    created_at: datetime

    class Config:
        from_attributes = True
