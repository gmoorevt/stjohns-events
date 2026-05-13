# Summerfest Event Dashboard

Internal dashboard for tracking the St. John's Hingham summer festival on Eventbrite. FastAPI + React, SQLite-backed, deployed via Docker on DigitalOcean.

## Features

- Real-time Eventbrite metrics (gross, net, ticket types, goal progress)
- Goal tracking and raw-data export (admin-only)
- Authentication required for all pages
  - Magic-link sign-in (email)
  - Email + password sign-in
- Admin user management (admin role can add/remove users and change roles)

## Tech Stack

- Backend: FastAPI, SQLAlchemy 2.0, SQLite, Alembic, passlib (bcrypt), python-jose (JWT)
- Frontend: React 18 + TypeScript, Vite 5, Tailwind, react-query, axios
- Auth: in-house. JWT in httpOnly cookie (30-day TTL), bcrypt-hashed passwords, magic-link tokens (15-min single-use)
- Email: Gmail SMTP via App Password
- Deploy: Docker Compose, Nginx reverse proxy, DigitalOcean droplet at 206.189.192.35

## Project Structure

```
summerfest/
├── backend/
│   ├── main.py              # routes
│   ├── auth_routes.py       # /api/auth/*
│   ├── admin_routes.py      # /api/admin/users/*
│   ├── db.py models.py      # SQLAlchemy
│   ├── security.py deps.py  # auth helpers
│   ├── email_sender.py      # Gmail SMTP
│   ├── startup.py           # admin bootstrap on app start
│   ├── alembic/             # migrations
│   └── data/                # SQLite db lives here in containers
├── frontend/
│   └── src/
│       ├── components/      # Dashboard, Admin, AdminUsers, Login, Account, Header, etc.
│       └── contexts/        # AuthContext
├── docker-compose.yml       # dev
├── docker-compose.prod.yml  # prod
├── nginx.conf               # prod nginx
├── deploy-production.sh     # one-shot droplet bootstrap
└── .env.example
```

## Local Development

```bash
# 1. Backend
cd backend
python -m venv ../venv && source ../venv/bin/activate
pip install -r requirements.txt
cp ../.env.example ../.env  # fill in real Eventbrite creds
alembic upgrade head
uvicorn main:app --reload

# 2. Frontend (separate terminal)
cd frontend
npm install
npm run dev
```

App runs at http://localhost:5173, API at http://localhost:8000. API docs at http://localhost:8000/docs.

## First Sign-In

1. Set `ADMIN_EMAIL` in `.env` (defaults to `geody.moore@gmail.com`). On first server start it's inserted as an admin user with no password.
2. Visit `/login`, choose "Email link", enter the admin email.
3. Open the link from the email, you'll be signed in.
4. Go to `/account` and set a password (so you can also use the Password tab later).
5. Go to `/admin/users` to add more users.

## Environment Variables

See `.env.example`. Critical ones:

| Var | Purpose |
|---|---|
| `EVENTBRITE_OAUTH_TOKEN` | Auth token for Eventbrite API |
| `EVENTBRITE_EVENT_ID` | The Eventbrite event to track (defaults to current year's event) |
| `ADMIN_EMAIL` | Bootstrapped admin user |
| `JWT_SECRET` | Session token signing key — `python -c 'import secrets; print(secrets.token_urlsafe(48))'` |
| `GMAIL_USER` / `GMAIL_APP_PASSWORD` | Sender account for magic-link emails (requires 2FA + App Password) |
| `APP_BASE_URL` | Used to build magic-link URLs in emails |
| `COOKIE_SECURE` | `true` in production (HTTPS), `false` for local dev |
| `BACKEND_CORS_ORIGINS` | Comma-separated allowed origins |

## Deployment

See [DEPLOY.md](DEPLOY.md). New droplet: `206.189.192.35`. Domains: `stjohns-hingham-events.org` and `api.stjohns-hingham-events.org`.
