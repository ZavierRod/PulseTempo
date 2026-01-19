# In app/core/apple_auth.py
import jwt
import httpx
from jwt import PyJWKClient

APPLE_JWKS_URL = "https://appleid.apple.com/auth/keys"
APPLE_ISSUER = "https://appleid.apple.com"
APP_BUNDLE_ID = "com.zavier.PulseTempo"


async def verify_apple_token(identity_token: str) -> dict:
    """Verify Apple identity token and return claims."""
    # Fetch Apple's public keys
    jwks_client = PyJWKClient(APPLE_JWKS_URL)
    signing_key = jwks_client.get_signing_key_from_jwt(identity_token)

    # Verify and decode
    claims = jwt.decode(
        identity_token,
        signing_key.key,
        algorithms=["RS256"],
        audience=APP_BUNDLE_ID,
        issuer=APPLE_ISSUER,
    )

    return {
        "apple_user_id": claims["sub"],
        "email": claims.get("email"),
    }
