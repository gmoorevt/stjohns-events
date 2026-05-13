from datetime import datetime
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, Response, status
from pydantic import BaseModel, EmailStr
from sqlalchemy.orm import Session

from db import get_db
from deps import require_admin
from models import User
from security import hash_password

Role = Literal["admin", "user"]

router = APIRouter(prefix="/api/admin", tags=["admin"])


class UserOut(BaseModel):
    id: int
    email: str
    role: str
    has_password: bool
    created_at: datetime


class CreateUserRequest(BaseModel):
    email: EmailStr
    role: Role = "user"
    password: str | None = None


class UpdateUserRequest(BaseModel):
    role: Role | None = None
    password: str | None = None


def _to_out(user: User) -> UserOut:
    return UserOut(
        id=user.id,
        email=user.email,
        role=user.role,
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
