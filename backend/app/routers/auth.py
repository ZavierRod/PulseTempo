from typing import Any
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from pydantic import BaseModel
from app import deps
from app.core import security
from app.crud import crud_user
from app.schemas.token import Token
from app.schemas.user import UserCreate

router = APIRouter()

class AppleLoginRequest(BaseModel):
    identity_token: str
    email: str | None = None
    first_name: str | None = None
    last_name: str | None = None

@router.post("/login", response_model=Token)
def login_access_token(
    login_req: AppleLoginRequest,
    db: Session = Depends(deps.get_db),
) -> Any:
    """
    OAuth2 compatible token login, get an access token for future requests
    """
    # TODO: Verify identity_token with Apple
    # For now, we'll assume the token is the apple_user_id for testing
    # In production, verify JWT signature and claims
    
    # Mock verification: assume token is the user ID
    apple_user_id = login_req.identity_token
    
    user = crud_user.get_by_apple_id(db, apple_user_id=apple_user_id)
    if not user:
        user = crud_user.create(db, obj_in=UserCreate(
            apple_user_id=apple_user_id,
            email=login_req.email
        ))
    
    access_token = security.create_access_token(user.id)
    refresh_token = security.create_refresh_token(user.id)
    
    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
    }
