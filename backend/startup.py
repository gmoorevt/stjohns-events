import logging
import os

from db import SessionLocal
from models import USER_STATUS_APPROVED, User

logger = logging.getLogger(__name__)


def ensure_admin_user() -> None:
    admin_email = os.getenv("ADMIN_EMAIL", "geody.moore@gmail.com").lower().strip()
    if not admin_email:
        return
    with SessionLocal() as db:
        existing = db.query(User).filter(User.email == admin_email).one_or_none()
        if existing is None:
            db.add(User(email=admin_email, role="admin", status=USER_STATUS_APPROVED, password_hash=None))
            db.commit()
            logger.info("Bootstrapped admin user %s (no password — sign in via magic link)", admin_email)
            return
        changed = False
        if existing.role != "admin":
            existing.role = "admin"
            changed = True
        if existing.status != USER_STATUS_APPROVED:
            existing.status = USER_STATUS_APPROVED
            changed = True
        if changed:
            db.commit()
            logger.info("Ensured %s is admin + approved", admin_email)
