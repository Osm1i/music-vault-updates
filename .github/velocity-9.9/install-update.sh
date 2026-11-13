#!/usr/bin/env bash
set -Eeuo pipefail

APP_ROOT="${MUSICVAULT_HOME:-/opt/music-vault}"
SERVICE="${MUSICVAULT_SERVICE:-music-vault.service}"
PORT="${MUSICVAULT_PORT:-8788}"
PKG_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$APP_ROOT/backups/vanguard-9.9.0-classic-profiles-$STAMP"
OWNER="$(stat -c '%U' "$APP_ROOT" 2>/dev/null || echo root)"
GROUP="$(stat -c '%G' "$APP_ROOT" 2>/dev/null || echo root)"
SERVICE_USER="$(systemctl show -p User --value "$SERVICE" 2>/dev/null || true)"
SERVICE_USER="${SERVICE_USER:-$OWNER}"
ROLLBACK_ACTIVE=0
HAD_MODULE=0
HAD_AUTH_JS=0
HAD_AUTH_CSS=0
HAD_VERSION=0
OLD_VERSION="$(cat "$APP_ROOT/data/installed_version.txt" 2>/dev/null || true)"

fail() { echo "ERROR: $*" >&2; return 1; }

rollback() {
  local status=$?
  if [[ "$ROLLBACK_ACTIVE" == "1" ]]; then
    trap - ERR
    set +e
    echo "ERROR: 9.9.0 failed its health checks. Restoring the prior application code..." >&2
    [[ -f "$BACKUP/app.py" ]] && cp -a "$BACKUP/app.py" "$APP_ROOT/app.py"
    [[ -f "$BACKUP/templates/index.html" ]] && cp -a "$BACKUP/templates/index.html" "$APP_ROOT/templates/index.html"
    if [[ "$HAD_MODULE" == "1" && -f "$BACKUP/mv98_accounts.py" ]]; then
      cp -a "$BACKUP/mv98_accounts.py" "$APP_ROOT/mv98_accounts.py"
    else
      rm -f "$APP_ROOT/mv98_accounts.py"
    fi
    if [[ "$HAD_AUTH_JS" == "1" && -f "$BACKUP/mv98-auth.js" ]]; then
      cp -a "$BACKUP/mv98-auth.js" "$APP_ROOT/static/mv98-auth.js"
    else
      rm -f "$APP_ROOT/static/mv98-auth.js"
    fi
    if [[ "$HAD_AUTH_CSS" == "1" && -f "$BACKUP/mv98-auth.css" ]]; then
      cp -a "$BACKUP/mv98-auth.css" "$APP_ROOT/static/mv98-auth.css"
    else
      rm -f "$APP_ROOT/static/mv98-auth.css"
    fi
    if [[ "$HAD_VERSION" == "1" && -f "$BACKUP/installed_version.txt" ]]; then
      cp -a "$BACKUP/installed_version.txt" "$APP_ROOT/data/installed_version.txt"
    else
      printf '%s\n' "$OLD_VERSION" > "$APP_ROOT/data/installed_version.txt"
    fi
    chown "$OWNER:$GROUP" "$APP_ROOT/app.py" "$APP_ROOT/templates/index.html" "$APP_ROOT/data/installed_version.txt" 2>/dev/null || true
    systemctl restart "$SERVICE"
    echo "Rollback completed. Source/database snapshot retained at: $BACKUP" >&2
    echo "The SQLite database was not modified by this update." >&2
    echo "Music files were never copied, moved or deleted." >&2
  fi
  exit "$status"
}
trap rollback ERR

[[ "$(id -u)" == "0" ]] || fail "Run through the Music Vault updater's root-owned install service."
[[ -d "$APP_ROOT" && -s "$APP_ROOT/app.py" && -s "$APP_ROOT/templates/index.html" && -d "$APP_ROOT/static" ]] || fail "Existing Music Vault source folders were not found at $APP_ROOT."
[[ "$OLD_VERSION" == "9.8.0" || "$OLD_VERSION" == "9.9.0" ]] || fail "Expected installed version 9.8.0; found '${OLD_VERSION:-unknown}'. No files were changed."
[[ -s "$PKG_DIR/payload/restore_classic_auth.py" ]] || fail "The classic-profile restore helper is missing."
[[ -s "$PKG_DIR/SHA256SUMS_9_9_0.txt" ]] || fail "The 9.9.0 checksum manifest is missing."

(cd "$PKG_DIR" && sha256sum -c SHA256SUMS_9_9_0.txt)
python3 "$PKG_DIR/tests/test_restore_classic.py"
python3 -m py_compile "$PKG_DIR/payload/restore_classic_auth.py"

mkdir -p "$BACKUP/templates" "$BACKUP/static" "$BACKUP/data"
cp -a "$APP_ROOT/app.py" "$BACKUP/app.py"
cp -a "$APP_ROOT/templates/index.html" "$BACKUP/templates/index.html"
if [[ -f "$APP_ROOT/mv98_accounts.py" ]]; then
  HAD_MODULE=1
  cp -a "$APP_ROOT/mv98_accounts.py" "$BACKUP/mv98_accounts.py"
fi
if [[ -f "$APP_ROOT/static/mv98-auth.js" ]]; then
  HAD_AUTH_JS=1
  cp -a "$APP_ROOT/static/mv98-auth.js" "$BACKUP/mv98-auth.js"
fi
if [[ -f "$APP_ROOT/static/mv98-auth.css" ]]; then
  HAD_AUTH_CSS=1
  cp -a "$APP_ROOT/static/mv98-auth.css" "$BACKUP/mv98-auth.css"
fi
if [[ -f "$APP_ROOT/data/installed_version.txt" ]]; then
  HAD_VERSION=1
  cp -a "$APP_ROOT/data/installed_version.txt" "$BACKUP/installed_version.txt"
fi
if [[ -s "$APP_ROOT/data/musicvault.db" ]]; then
  python3 - "$APP_ROOT/data/musicvault.db" "$BACKUP/musicvault.db" <<'PY'
import sqlite3,sys
src=sqlite3.connect(sys.argv[1],timeout=30)
dst=sqlite3.connect(sys.argv[2])
try:
    src.backup(dst)
finally:
    dst.close()
    src.close()
PY
  chmod 0600 "$BACKUP/musicvault.db"
fi

TMP="$APP_ROOT/.mv99-stage-$STAMP"
mkdir -p "$TMP/templates"
cp -a "$APP_ROOT/app.py" "$TMP/app.py"
cp -a "$APP_ROOT/templates/index.html" "$TMP/templates/index.html"
python3 "$PKG_DIR/payload/restore_classic_auth.py" "$TMP/app.py" "$TMP/templates/index.html"
python3 -m py_compile "$TMP/app.py"
if grep -Eq 'install_music_vault_accounts|mv98_accounts' "$TMP/app.py"; then
  fail "Account startup code remains after staging."
fi
if grep -Eq 'mv98-auth|mv98-auth-pending' "$TMP/templates/index.html"; then
  fail "Secure sign-in assets remain referenced after staging."
fi

ROLLBACK_ACTIVE=1
systemctl stop "$SERVICE"
install -o "$OWNER" -g "$GROUP" -m 0644 "$TMP/app.py" "$APP_ROOT/app.py"
install -o "$OWNER" -g "$GROUP" -m 0644 "$TMP/templates/index.html" "$APP_ROOT/templates/index.html"
rm -f "$APP_ROOT/mv98_accounts.py" "$APP_ROOT/static/mv98-auth.js" "$APP_ROOT/static/mv98-auth.css"
printf '9.9.0\n' > "$APP_ROOT/data/installed_version.txt"
chown "$OWNER:$GROUP" "$APP_ROOT/app.py" "$APP_ROOT/templates/index.html" "$APP_ROOT/data/installed_version.txt"
chmod 0644 "$APP_ROOT/data/installed_version.txt"
rm -rf "$TMP"

python3 -m py_compile "$APP_ROOT/app.py"
systemctl restart "$SERVICE"
READY=0
for attempt in $(seq 1 35); do
  if curl --silent --show-error --fail --max-time 4 "http://127.0.0.1:$PORT/" -o /tmp/mv99-home.html 2>/dev/null &&
     curl --silent --show-error --fail --max-time 4 "http://127.0.0.1:$PORT/api/status" -o /tmp/mv99-api-status.json 2>/dev/null; then
    READY=1
    break
  fi
  sleep 2
done
[[ "$READY" == "1" ]] || fail "Music Vault did not pass the home-page and original API health checks."
systemctl is-active --quiet "$SERVICE" || fail "Music Vault service is not active."
if grep -Eq 'mv98-auth|mv98-auth-pending|Secure Sign In' /tmp/mv99-home.html; then
  fail "The home page still references the 9.8 sign-in interface."
fi
[[ ! -e "$APP_ROOT/mv98_accounts.py" ]] || fail "The 9.8 account helper remains installed."
[[ ! -e "$APP_ROOT/static/mv98-auth.js" && ! -e "$APP_ROOT/static/mv98-auth.css" ]] || fail "A 9.8 sign-in asset remains installed."

ROLLBACK_ACTIVE=0
trap - ERR

echo
echo "============================================================"
echo " MUSIC VAULT 9.9.0 — CLASSIC PROFILE RESTORE"
echo "============================================================"
echo "Secure account sign-in: REMOVED"
echo "Original profile picker and shared Library flow: RESTORED"
echo "9.6 performance, playback, background playback and EQ: PRESERVED"
echo "9.7 responsive presentation: PRESERVED"
echo "Original API health check: PASSED"
echo "Database: preserved; no tables or rows were dropped"
echo "Music files: untouched"
echo "Backup: $BACKUP"
echo "============================================================"
