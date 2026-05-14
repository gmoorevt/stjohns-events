import logging
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, Response, status
from pydantic import BaseModel, EmailStr
from sqlalchemy.orm import Session

from db import get_db
from deps import get_current_user
from email_sender import (
    EmailNotConfigured,
    send_access_request_email,
    send_magic_link_email,
)
from models import (
    USER_STATUS_APPROVED,
    USER_STATUS_PENDING,
    MagicLink,
    User,
)
from security import (
    COOKIE_NAME,
    COOKIE_SECURE,
    JWT_TTL_DAYS,
    MAGIC_LINK_TTL_MINUTES,
    create_session_token,
    generate_magic_link_token,
    hash_magic_token,
    verify_password,
)

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/auth", tags=["auth"])


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class MagicLinkRequest(BaseModel):
    email: EmailStr


class UserResponse(BaseModel):
    id: int
    email: str
    role: str


def _set_session_cookie(response: Response, user_id: int) -> None:
    token = create_session_token(user_id)
    response.set_cookie(
        key=COOKIE_NAME,
        value=token,
        max_age=JWT_TTL_DAYS * 24 * 3600,
        httponly=True,
        secure=COOKIE_SECURE,
        samesite="lax",
        path="/",
    )


@router.post("/login")
def login(payload: LoginRequest, response: Response, db: Session = Depends(get_db)) -> UserResponse:
    user = db.query(User).filter(User.email == payload.email.lower()).one_or_none()
    if user is None or user.password_hash is None or not verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid email or password")
    if user.status != USER_STATUS_APPROVED:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Account not approved")
    _set_session_cookie(response, user.id)
    return UserResponse(id=user.id, email=user.email, role=user.role)


def _issue_magic_link(db: Session, user: User) -> str:
    raw, digest = generate_magic_link_token()
    db.add(MagicLink(
        token_hash=digest,
        user_id=user.id,
        expires_at=datetime.utcnow() + timedelta(minutes=MAGIC_LINK_TTL_MINUTES),
    ))
    db.commit()
    return raw


@router.post("/magic-link", status_code=status.HTTP_204_NO_CONTENT)
def request_magic_link(payload: MagicLinkRequest, db: Session = Depends(get_db)) -> Response:
    email = payload.email.lower()
    user = db.query(User).filter(User.email == email).one_or_none()

    if user is None:
        new_user = User(email=email, role="user", status=USER_STATUS_PENDING)
        db.add(new_user)
        db.commit()
        admin_email = (
            db.query(User)
            .filter(User.role == "admin", User.status == USER_STATUS_APPROVED)
            .order_by(User.created_at)
            .first()
        )
        if admin_email is not None:
            try:
                send_access_request_email(admin_email.email, email)
            except EmailNotConfigured:
                logger.error("Email service not configured — access request not emailed to admin")
            except Exception:
                logger.exception("Failed to send access request email to admin")
    elif user.status == USER_STATUS_APPROVED:
        raw = _issue_magic_link(db, user)
        try:
            send_magic_link_email(user.email, raw)
        except EmailNotConfigured:
            logger.error("Email service not configured — magic link generated but not sent")
            raise HTTPException(status_code=503, detail="Email service not configured")
        except Exception:
            logger.exception("Failed to send magic link email")
            raise HTTPException(status_code=502, detail="Failed to send email")
    # pending/rejected: silent no-op to avoid leaking account state
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/magic-link/verify")
def verify_magic_link(token: str, response: Response, db: Session = Depends(get_db)) -> UserResponse:
    digest = hash_magic_token(token)
    link = db.query(MagicLink).filter(MagicLink.token_hash == digest).one_or_none()
    now = datetime.utcnow()
    if link is None or link.used_at is not None or link.expires_at < now:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired link")
    link.used_at = now
    user = db.get(User, link.user_id)
    if user is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")
    if user.status != USER_STATUS_APPROVED:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Account not approved")
    db.commit()
    _set_session_cookie(response, user.id)
    return UserResponse(id=user.id, email=user.email, role=user.role)


@router.post("/logout")
def logout() -> Response:
    resp = Response(status_code=status.HTTP_204_NO_CONTENT)
    resp.delete_cookie(key=COOKIE_NAME, path="/")
    return resp


@router.get("/me")
def me(user: User = Depends(get_current_user)) -> UserResponse:
    return UserResponse(id=user.id, email=user.email, role=user.role)


class SetPasswordRequest(BaseModel):
    password: str


@router.post("/set-password", status_code=status.HTTP_204_NO_CONTENT)
def set_password(
    payload: SetPasswordRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> Response:
    from security import hash_password

    if len(payload.password) < 8:
        raise HTTPException(status_code=400, detail="Password must be at least 8 characters")
    user.password_hash = hash_password(payload.password)
    db.add(user)
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
