import os
import smtplib
from email.message import EmailMessage

GMAIL_USER = os.getenv("GMAIL_USER", "")
GMAIL_APP_PASSWORD = os.getenv("GMAIL_APP_PASSWORD", "")
APP_BASE_URL = os.getenv("APP_BASE_URL", "http://localhost:5173").rstrip("/")


class EmailNotConfigured(Exception):
    pass


def _send(to_email: str, subject: str, body: str) -> None:
    if not GMAIL_USER or not GMAIL_APP_PASSWORD:
        raise EmailNotConfigured("GMAIL_USER and GMAIL_APP_PASSWORD must be set")
    msg = EmailMessage()
    msg["Subject"] = subject
    msg["From"] = GMAIL_USER
    msg["To"] = to_email
    msg.set_content(body)
    with smtplib.SMTP("smtp.gmail.com", 587) as smtp:
        smtp.starttls()
        smtp.login(GMAIL_USER, GMAIL_APP_PASSWORD)
        smtp.send_message(msg)


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
