from typing import Optional
from sqlalchemy.orm import Session
from sqlalchemy import or_
from app.models.user import User
from app.schemas.user import UserCreateApple, UserCreateEmail
from app.core.security import get_password_hash

def get(db: Session, user_id: str) -> Optional[User]:
    return db.query(User).filter(User.id == user_id).first()

def get_by_apple_id(db: Session, apple_user_id: str) -> Optional[User]:
    return db.query(User).filter(User.apple_user_id == apple_user_id).first()

def get_by_email(db: Session, email: str) -> Optional[User]:
    return db.query(User).filter(User.email == email).first()

def get_by_username(db: Session, username: str) -> Optional[User]:
    return db.query(User).filter(User.username == username).first()

def create(db: Session, obj_in: UserCreateApple) -> User:
    """Create user from Apple Sign In"""
    db_obj = User(
        apple_user_id=obj_in.apple_user_id,
        email=obj_in.email,
        username=obj_in.username,
        first_name=obj_in.first_name,
        last_name=obj_in.last_name
    )
    db.add(db_obj)
    db.commit()
    db.refresh(db_obj)
    return db_obj

def create_with_email(db: Session, obj_in: UserCreateEmail) -> User:
    """Create user with email, username, and password"""
    db_obj = User(
        email=obj_in.email,
        username=obj_in.username,
        hashed_password=get_password_hash(obj_in.password),
        first_name=obj_in.first_name,
        last_name=obj_in.last_name
    )
    db.add(db_obj)
    db.commit()
    db.refresh(db_obj)
    return db_obj

def authenticate_by_identifier(db: Session, identifier: str, password: str) -> Optional[User]:
    """Authenticate user with email or username and password"""
    from app.core.security import verify_password
    # Try to find user by email or username
    user = db.query(User).filter(
        or_(User.email == identifier, User.username == identifier)
    ).first()
    if not user:
        return None
    if not user.hashed_password:
        return None  # User signed up with Apple, not email
    if not verify_password(password, user.hashed_password):
        return None
    return user

def authenticate_email(db: Session, email: str, password: str) -> Optional[User]:
    """Authenticate user with email and password (legacy, kept for compatibility)"""
    return authenticate_by_identifier(db, identifier=email, password=password)
