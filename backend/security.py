import hashlib
import os
import secrets
from datetime import datetime, timedelta, timezone

from jose import JWTError, jwt
from passlib.context import CryptContext

JWT_SECRET = os.getenv("JWT_SECRET", "dev-only-insecure-secret-change-me")
JWT_ALG = "HS256"
JWT_TTL_DAYS = int(os.getenv("JWT_TTL_DAYS", "30"))
COOKIE_NAME = "summerfest_session"
COOKIE_SECURE = os.getenv("COOKIE_SECURE", "false").lower() == "true"

MAGIC_LINK_TTL_MINUTES = 15

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def hash_password(password: str) -> str:
    return pwd_context.hash(password)


def verify_password(password: str, password_hash: str) -> bool:
    return pwd_context.verify(password, password_hash)


def create_session_token(user_id: int) -> str:
    now = datetime.now(timezone.utc)
    payload = {
        "sub": str(user_id),
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(days=JWT_TTL_DAYS)).timestamp()),
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALG)


def decode_session_token(token: str) -> int | None:
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALG])
        return int(payload["sub"])
    except (JWTError, KeyError, ValueError):
        return None


def generate_magic_link_token() -> tuple[str, str]:
    """Return (raw_token, sha256_hash). Store only the hash; email the raw token."""
    raw = secrets.token_urlsafe(32)
    digest = hashlib.sha256(raw.encode()).hexdigest()
    return raw, digest


def hash_magic_token(raw: str) -> str:
    return hashlib.sha256(raw.encode()).hexdigest()
