#!/usr/bin/env bash
# End-to-end test of the magic-link sign-in flow against the live API.
#
# Steps:
#   1) POST /api/auth/magic-link  (exercises Postmark send path)
#   2) Generate a fresh raw token directly via the backend container, so we
#      don't have to scrape email to complete the flow.
#   3) GET  /api/auth/magic-link/verify?token=<raw>  (captures session cookie)
#   4) GET  /api/auth/me  with the cookie (asserts authenticated user)
#
# Usage: scripts/test_magic_link.sh [email]

set -euo pipefail

API="${API:-https://api.stjohns-hingham-events.org}"
DROPLET="${DROPLET:-root@206.189.192.35}"
TEST_EMAIL="${1:-gmoore@downeastventures.com}"
COOKIE_NAME="summerfest_session"

red()   { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
step()  { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
fail()  { red "FAIL: $*"; exit 1; }

step "1) POST /api/auth/magic-link  (email: $TEST_EMAIL)"
status=$(curl -sS -o /dev/null -w '%{http_code}' \
  -X POST "$API/api/auth/magic-link" \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"$TEST_EMAIL\"}")
[ "$status" = "204" ] || fail "expected 204, got $status"
green "OK: 204 No Content (Postmark accepted send if logs show no error)"

step "2) Generate fresh raw token via backend (bypasses email)"
RAW=$(ssh "$DROPLET" "docker exec summerfest-backend python -c \"
from db import SessionLocal
from models import User
from auth_routes import _issue_magic_link
with SessionLocal() as db:
    user = db.query(User).filter(User.email == '$TEST_EMAIL').one_or_none()
    if user is None:
        raise SystemExit('no user with that email')
    print(_issue_magic_link(db, user))
    db.commit()
\"")
[ -n "$RAW" ] || fail "no token generated"
green "OK: token issued (length ${#RAW})"

step "3) GET /api/auth/magic-link/verify?token=...  (capturing cookie)"
JAR=$(mktemp)
trap 'rm -f "$JAR"' EXIT
status=$(curl -sS -o /tmp/verify.body -w '%{http_code}' \
  -c "$JAR" \
  "$API/api/auth/magic-link/verify?token=$RAW")
[ "$status" = "200" ] || fail "verify returned $status: $(cat /tmp/verify.body)"
grep -q "$COOKIE_NAME" "$JAR" || fail "no $COOKIE_NAME cookie set; jar=$(cat "$JAR")"
green "OK: 200 + $COOKIE_NAME cookie set"
echo "    body: $(cat /tmp/verify.body)"

step "4) GET /api/auth/me  with cookie"
me=$(curl -sS -b "$JAR" "$API/api/auth/me")
echo "$me" | grep -q "\"email\":\"$TEST_EMAIL\"" || fail "/me did not return $TEST_EMAIL: $me"
echo "$me" | grep -q '"role":"admin"' || fail "/me did not show admin role: $me"
green "OK: /me confirms $me"

step "All checks passed."
