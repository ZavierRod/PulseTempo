from typing import Any, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from pydantic import BaseModel
from jose import jwt, JWTError
from app import deps
from app.core import security
from app.crud import crud_user
from app.schemas.token import Token
from app.schemas.user import UserCreateApple, UserCreateEmail, UserLoginEmail, UserResponse
from app.core.apple_auth import verify_apple_token

router = APIRouter()


# ═══════════════════════════════════════════════════════════
# EMAIL/PASSWORD AUTHENTICATION
# ═══════════════════════════════════════════════════════════

@router.post("/register", response_model=Token)
def register_with_email(
    user_in: UserCreateEmail,
    db: Session = Depends(deps.get_db)
):
    """
    Register a new user with email, username, and password.
    Username must be unique.
    """
    # Check if email already exists
    existing_user = crud_user.get_by_email(db, email=user_in.email)
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="An account with this email already exists"
        )

    # Check if username already taken
    existing_username = crud_user.get_by_username(db, username=user_in.username)
    if existing_username:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="This username is already taken"
        )

    # Create user
    user = crud_user.create_with_email(db, obj_in=user_in)

    # Generate tokens
    access_token = security.create_access_token(user.id)
    refresh_token = security.create_refresh_token(user.id)

    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
    }


@router.post("/login/email", response_model=Token)
def login_with_email(
    login_in: UserLoginEmail,
    db: Session = Depends(deps.get_db)
):
    """
    Login with email or username and password.
    The 'identifier' field accepts either an email address or a username.
    """
    user = crud_user.authenticate_by_identifier(
        db, identifier=login_in.identifier, password=login_in.password)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email/username or password"
        )

    access_token = security.create_access_token(user.id)
    refresh_token = security.create_refresh_token(user.id)

    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
    }


@router.get("/me", response_model=UserResponse)
def get_current_user_info(
    current_user=Depends(deps.get_current_user)
):
    """
    Get current authenticated user's info.
    """
    return current_user


# ═══════════════════════════════════════════════════════════
# TOKEN REFRESH
# ═══════════════════════════════════════════════════════════

class RefreshTokenRequest(BaseModel):
    refresh_token: str


@router.post("/refresh", response_model=Token)
def refresh_access_token(
    body: RefreshTokenRequest,
    db: Session = Depends(deps.get_db)
):
    """
    Exchange a valid refresh token for a new access + refresh token pair.
    """
    try:
        payload = jwt.decode(
            body.refresh_token, security.SECRET_KEY, algorithms=[
                security.ALGORITHM]
        )
        # Ensure this is actually a refresh token (has type="refresh")
        if payload.get("type") != "refresh":
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token type",
            )
        user_id = payload.get("sub")
        if not user_id:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token payload",
            )
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Refresh token expired or invalid",
        )

    user = crud_user.get(db, user_id=user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    access_token = security.create_access_token(user.id)
    refresh_token = security.create_refresh_token(user.id)

    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
    }


# ═══════════════════════════════════════════════════════════
# APPLE SIGN IN (existing)
# ═══════════════════════════════════════════════════════════

class AppleLoginRequest(BaseModel):
    identity_token: str
    email: Optional[str] = None
    first_name: Optional[str] = None
    last_name: Optional[str] = None


@router.post("/login/apple", response_model=Token)
async def login_with_apple(login_req: AppleLoginRequest, db: Session = Depends(deps.get_db)):
    """
    Login or register with Apple Sign In.
    """
    # Verify token with Apple
    verified = await verify_apple_token(login_req.identity_token)

    user = crud_user.get_by_apple_id(
        db, apple_user_id=verified["apple_user_id"])
    if not user:
        user = crud_user.create(db, obj_in=UserCreateApple(
            apple_user_id=verified["apple_user_id"],
            email=verified["email"] or login_req.email,
            first_name=login_req.first_name,
            last_name=login_req.last_name
        ))

    access_token = security.create_access_token(user.id)
    refresh_token = security.create_refresh_token(user.id)

    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
    }


# Keep the old /login endpoint for backwards compatibility (maps to Apple)
@router.post("/login", response_model=Token, include_in_schema=False)
async def login_access_token(login_req: AppleLoginRequest, db: Session = Depends(deps.get_db)):
    """Legacy endpoint - redirects to Apple login"""
    return await login_with_apple(login_req, db)
