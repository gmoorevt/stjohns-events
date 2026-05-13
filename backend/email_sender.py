import os
import smtplib
from email.message import EmailMessage

GMAIL_USER = os.getenv("GMAIL_USER", "")
GMAIL_APP_PASSWORD = os.getenv("GMAIL_APP_PASSWORD", "")
APP_BASE_URL = os.getenv("APP_BASE_URL", "http://localhost:5173").rstrip("/")


class EmailNotConfigured(Exception):
    pass


def send_magic_link_email(to_email: str, token: str) -> None:
    if not GMAIL_USER or not GMAIL_APP_PASSWORD:
        raise EmailNotConfigured("GMAIL_USER and GMAIL_APP_PASSWORD must be set")

    link = f"{APP_BASE_URL}/auth/verify?token={token}"
    msg = EmailMessage()
    msg["Subject"] = "Your Summerfest sign-in link"
    msg["From"] = GMAIL_USER
    msg["To"] = to_email
    msg.set_content(
        f"Click to sign in to the Summerfest dashboard:\n\n{link}\n\n"
        f"This link expires in 15 minutes and can only be used once.\n"
        f"If you didn't request this, you can ignore this email."
    )

    with smtplib.SMTP("smtp.gmail.com", 587) as smtp:
        smtp.starttls()
        smtp.login(GMAIL_USER, GMAIL_APP_PASSWORD)
        smtp.send_message(msg)
