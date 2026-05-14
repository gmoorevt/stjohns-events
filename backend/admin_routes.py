import logging
from datetime import datetime, timedelta
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, Response, status
from pydantic import BaseModel, EmailStr
from sqlalchemy.orm import Session

from db import get_db
from deps import require_admin
from email_sender import EmailNotConfigured, send_approval_email
from models import (
    USER_STATUS_APPROVED,
    USER_STATUS_PENDING,
    USER_STATUS_REJECTED,
    MagicLink,
    User,
)
from security import MAGIC_LINK_TTL_MINUTES, generate_magic_link_token, hash_password

logger = logging.getLogger(__name__)

Role = Literal["admin", "user"]
Status = Literal["pending", "approved", "rejected"]

router = APIRouter(prefix="/api/admin", tags=["admin"])


class UserOut(BaseModel):
    id: int
    email: str
    role: str
    status: str
    has_password: bool
    created_at: datetime


class CreateUserRequest(BaseModel):
    email: EmailStr
    role: Role = "user"
    password: str | None = None
    status: Status = "approved"


class UpdateUserRequest(BaseModel):
    role: Role | None = None
    password: str | None = None


def _to_out(user: User) -> UserOut:
    return UserOut(
        id=user.id,
        email=user.email,
        role=user.role,
        status=user.status,
        has_password=user.password_hash is not None,
        created_at=user.created_at,
    )


@router.get("/users")
def list_users(_: User = Depends(require_admin), db: Session = Depends(get_db)) -> list[UserOut]:
    users = db.query(User).order_by(User.created_at).all()
    return [_to_out(u) for u in users]


@router.post("/users", status_code=status.HTTP_201_CREATED)
def create_user(
    payload: CreateUserRequest,
    _: User = Depends(require_admin),
    db: Session = Depends(get_db),
) -> UserOut:
    email = payload.email.lower()
    if db.query(User).filter(User.email == email).one_or_none() is not None:
        raise HTTPException(status_code=409, detail="User already exists")
    if payload.password is not None and len(payload.password) < 8:
        raise HTTPException(status_code=400, detail="Password must be at least 8 characters")
    user = User(
        email=email,
        role=payload.role,
        status=payload.status,
        password_hash=hash_password(payload.password) if payload.password else None,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return _to_out(user)


@router.patch("/users/{user_id}")
def update_user(
    user_id: int,
    payload: UpdateUserRequest,
    current: User = Depends(require_admin),
    db: Session = Depends(get_db),
) -> UserOut:
    user = db.get(User, user_id)
    if user is None:
        raise HTTPException(status_code=404, detail="User not found")
    if payload.role is not None:
        if user.id == current.id and payload.role != "admin":
            raise HTTPException(status_code=400, detail="Cannot demote yourself")
        user.role = payload.role
    if payload.password is not None:
        if len(payload.password) < 8:
            raise HTTPException(status_code=400, detail="Password must be at least 8 characters")
        user.password_hash = hash_password(payload.password)
    db.commit()
    db.refresh(user)
    return _to_out(user)


@router.post("/users/{user_id}/approve")
def approve_user(
    user_id: int,
    _: User = Depends(require_admin),
    db: Session = Depends(get_db),
) -> UserOut:
    user = db.get(User, user_id)
    if user is None:
        raise HTTPException(status_code=404, detail="User not found")
    if user.status == USER_STATUS_APPROVED:
        return _to_out(user)

    user.status = USER_STATUS_APPROVED
    raw, digest = generate_magic_link_token()
    db.add(MagicLink(
        token_hash=digest,
        user_id=user.id,
        expires_at=datetime.utcnow() + timedelta(minutes=MAGIC_LINK_TTL_MINUTES),
    ))
    db.commit()
    db.refresh(user)
    try:
        send_approval_email(user.email, raw)
    except EmailNotConfigured:
        logger.error("Email service not configured — approval email not sent to %s", user.email)
        raise HTTPException(status_code=503, detail="Email service not configured")
    except Exception:
        logger.exception("Failed to send approval email to %s", user.email)
        raise HTTPException(status_code=502, detail="Failed to send approval email")
    return _to_out(user)


@router.post("/users/{user_id}/reject")
def reject_user(
    user_id: int,
    current: User = Depends(require_admin),
    db: Session = Depends(get_db),
) -> UserOut:
    user = db.get(User, user_id)
    if user is None:
        raise HTTPException(status_code=404, detail="User not found")
    if user.id == current.id:
        raise HTTPException(status_code=400, detail="Cannot reject yourself")
    user.status = USER_STATUS_REJECTED
    db.commit()
    db.refresh(user)
    return _to_out(user)


@router.delete("/users/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_user(
    user_id: int,
    current: User = Depends(require_admin),
    db: Session = Depends(get_db),
) -> Response:
    if user_id == current.id:
        raise HTTPException(status_code=400, detail="Cannot delete yourself")
    user = db.get(User, user_id)
    if user is None:
        raise HTTPException(status_code=404, detail="User not found")
    db.delete(user)
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
