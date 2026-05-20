import logging
import os

import httpx

POSTMARK_SERVER_TOKEN = os.getenv("POSTMARK_SERVER_TOKEN", "")
POSTMARK_FROM_EMAIL = os.getenv("POSTMARK_FROM_EMAIL", "")
POSTMARK_MESSAGE_STREAM = os.getenv("POSTMARK_MESSAGE_STREAM", "outbound")
APP_BASE_URL = os.getenv("APP_BASE_URL", "http://localhost:5173").rstrip("/")
ENVIRONMENT = os.getenv("ENVIRONMENT", "production").lower()

POSTMARK_URL = "https://api.postmarkapp.com/email"

logger = logging.getLogger(__name__)


class EmailNotConfigured(Exception):
    pass


def _send(to_email: str, subject: str, body: str) -> None:
    if not POSTMARK_SERVER_TOKEN or not POSTMARK_FROM_EMAIL:
        if ENVIRONMENT == "development":
            logger.warning(
                "[dev] Postmark not configured — logging email instead of sending.\n"
                "  To: %s\n  Subject: %s\n  Body:\n%s",
                to_email, subject, body,
            )
            return
        raise EmailNotConfigured(
            "POSTMARK_SERVER_TOKEN and POSTMARK_FROM_EMAIL must be set"
        )
    payload = {
        "From": POSTMARK_FROM_EMAIL,
        "To": to_email,
        "Subject": subject,
        "TextBody": body,
        "MessageStream": POSTMARK_MESSAGE_STREAM,
    }
    headers = {
        "Accept": "application/json",
        "Content-Type": "application/json",
        "X-Postmark-Server-Token": POSTMARK_SERVER_TOKEN,
    }
    resp = httpx.post(POSTMARK_URL, json=payload, headers=headers, timeout=15.0)
    # Postmark returns 200 with ErrorCode=0 on success; 422 with ErrorCode!=0 on failure.
    if resp.status_code != 200 or resp.json().get("ErrorCode", -1) != 0:
        logger.error("Postmark send failed: %s %s", resp.status_code, resp.text)
        resp.raise_for_status()
        raise RuntimeError(f"Postmark returned non-zero ErrorCode: {resp.text}")


def send_magic_link_email(to_email: str, token: str) -> None:
    link = f"{APP_BASE_URL}/auth/verify?token={token}"
    _send(
        to_email,
        "Your Summerfest sign-in link",
        f"Click to sign in to the Summerfest dashboard:\n\n{link}\n\n"
        f"This link expires in 15 minutes and can only be used once.\n"
        f"If you didn't request this, you can ignore this email.",
    )


def send_access_request_email(admin_email: str, requester_email: str) -> None:
    link = f"{APP_BASE_URL}/admin"
    _send(
        admin_email,
        f"New Summerfest access request: {requester_email}",
        f"{requester_email} has requested access to the Summerfest dashboard.\n\n"
        f"Review pending requests:\n{link}\n",
    )


def send_approval_email(to_email: str, token: str) -> None:
    link = f"{APP_BASE_URL}/auth/verify?token={token}"
    _send(
        to_email,
        "You've been approved for the Summerfest dashboard",
        f"An admin approved your access to the Summerfest dashboard.\n\n"
        f"Click to sign in:\n\n{link}\n\n"
        f"This link expires in 15 minutes and can only be used once.\n"
        f"Future sign-ins: request a fresh link any time from the sign-in page.",
    )
