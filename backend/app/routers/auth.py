from typing import Any
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from pydantic import BaseModel
from app import deps
from app.core import security
from app.crud import crud_user
from app.schemas.token import Token
from app.schemas.user import UserCreate
from app.core.apple_auth import verify_apple_token
router = APIRouter()


class AppleLoginRequest(BaseModel):
    identity_token: str
    email: str | None = None
    first_name: str | None = None
    last_name: str | None = None


@router.post("/login", response_model=Token)
async def login_access_token(login_req: AppleLoginRequest, db: Session = Depends(deps.get_db)):
    # Verify token with Apple
    verified = await verify_apple_token(login_req.identity_token)

    user = crud_user.get_by_apple_id(
        db, apple_user_id=verified["apple_user_id"])
    if not user:
        user = crud_user.create(db, obj_in=UserCreate(
            apple_user_id=verified["apple_user_id"],
            email=verified["email"] or login_req.email
        ))

    access_token = security.create_access_token(user.id)
    refresh_token = security.create_refresh_token(user.id)

    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
    }
