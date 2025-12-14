from typing import Optional
from sqlalchemy.orm import Session
from app.models.user import User
from app.schemas.user import UserCreate

def get(db: Session, user_id: str) -> Optional[User]:
    return db.query(User).filter(User.id == user_id).first()

def get_by_apple_id(db: Session, apple_user_id: str) -> Optional[User]:
    return db.query(User).filter(User.apple_user_id == apple_user_id).first()

def create(db: Session, obj_in: UserCreate) -> User:
    db_obj = User(
        apple_user_id=obj_in.apple_user_id,
        email=obj_in.email
    )
    db.add(db_obj)
    db.commit()
    db.refresh(db_obj)
    return db_obj
