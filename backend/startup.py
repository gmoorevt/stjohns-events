import logging
import os

from db import SessionLocal
from models import User

logger = logging.getLogger(__name__)


def ensure_admin_user() -> None:
    admin_email = os.getenv("ADMIN_EMAIL", "geody.moore@gmail.com").lower().strip()
    if not admin_email:
        return
    with SessionLocal() as db:
        existing = db.query(User).filter(User.email == admin_email).one_or_none()
        if existing is None:
            db.add(User(email=admin_email, role="admin", password_hash=None))
            db.commit()
            logger.info("Bootstrapped admin user %s (no password — sign in via magic link)", admin_email)
        elif existing.role != "admin":
            existing.role = "admin"
            db.commit()
            logger.info("Promoted %s to admin", admin_email)
