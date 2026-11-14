#!/usr/bin/env bash
set -Eeuo pipefail

APP_ROOT="${MUSICVAULT_HOME:-/opt/music-vault}"
SERVICE="${MUSICVAULT_SERVICE:-music-vault.service}"
PORT="${MUSICVAULT_PORT:-8788}"
PKG_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$APP_ROOT/backups/vanguard-9.10.0-profile-picker-$STAMP"
OWNER="$(stat -c '%U' "$APP_ROOT" 2>/dev/null || echo root)"
GROUP="$(stat -c '%G' "$APP_ROOT" 2>/dev/null || echo root)"
OLD_VERSION="$(cat "$APP_ROOT/data/installed_version.txt" 2>/dev/null || true)"
ROLLBACK_ACTIVE=0
HAD_SECRET=0
HAD_MODULE=0
HAD_AUTH_JS=0
HAD_AUTH_CSS=0
HAD_PICKER_JS=0
HAD_PICKER_CSS=0
HAD_VERSION=0

fail() { echo "ERROR: $*" >&2; return 1; }

rollback() {
  local status=$?
  if [[ "$ROLLBACK_ACTIVE" == "1" ]]; then
    trap - ERR
    set +e
    echo "ERROR: 9.10.0 failed a health check. Restoring the previous app and database..." >&2
    systemctl stop "$SERVICE" 2>/dev/null || true
    [[ -f "$BACKUP/app.py" ]] && cp -a "$BACKUP/app.py" "$APP_ROOT/app.py"
    [[ -f "$BACKUP/templates/index.html" ]] && cp -a "$BACKUP/templates/index.html" "$APP_ROOT/templates/index.html"
    [[ -f "$BACKUP/data/musicvault.db" ]] && cp -a "$BACKUP/data/musicvault.db" "$APP_ROOT/data/musicvault.db"
    if [[ "$HAD_SECRET" == "1" && -f "$BACKUP/data/.session-secret" ]]; then
      cp -a "$BACKUP/data/.session-secret" "$APP_ROOT/data/.session-secret"
    else
      rm -f "$APP_ROOT/data/.session-secret" "$APP_ROOT/data/.session-secret.tmp"
    fi
    if [[ "$HAD_MODULE" == "1" && -f "$BACKUP/mv98_accounts.py" ]]; then cp -a "$BACKUP/mv98_accounts.py" "$APP_ROOT/mv98_accounts.py"; fi
    if [[ "$HAD_AUTH_JS" == "1" && -f "$BACKUP/mv98-auth.js" ]]; then cp -a "$BACKUP/mv98-auth.js" "$APP_ROOT/static/mv98-auth.js"; fi
    if [[ "$HAD_AUTH_CSS" == "1" && -f "$BACKUP/mv98-auth.css" ]]; then cp -a "$BACKUP/mv98-auth.css" "$APP_ROOT/static/mv98-auth.css"; fi
    if [[ "$HAD_PICKER_JS" == "1" && -f "$BACKUP/mv101-profile-chooser.js" ]]; then cp -a "$BACKUP/mv101-profile-chooser.js" "$APP_ROOT/static/mv101-profile-chooser.js"; else rm -f "$APP_ROOT/static/mv101-profile-chooser.js"; fi
    if [[ "$HAD_PICKER_CSS" == "1" && -f "$BACKUP/mv101-profile-chooser.css" ]]; then cp -a "$BACKUP/mv101-profile-chooser.css" "$APP_ROOT/static/mv101-profile-chooser.css"; else rm -f "$APP_ROOT/static/mv101-profile-chooser.css"; fi
    if [[ "$HAD_VERSION" == "1" && -f "$BACKUP/installed_version.txt" ]]; then cp -a "$BACKUP/installed_version.txt" "$APP_ROOT/data/installed_version.txt"; else printf '%s\n' "$OLD_VERSION" > "$APP_ROOT/data/installed_version.txt"; fi
    chown "$OWNER:$GROUP" "$APP_ROOT/app.py" "$APP_ROOT/templates/index.html" "$APP_ROOT/data/installed_version.txt" 2>/dev/null || true
    systemctl restart "$SERVICE"
    echo "Rollback completed. Complete database/source snapshot retained at: $BACKUP" >&2
    echo "No tracks, legacy playlists, favorites, listening history, or music files were deleted." >&2
  fi
  exit "$status"
}
trap rollback ERR

[[ "$(id -u)" == "0" ]] || fail "Run through the Music Vault updater's root-owned install service."
[[ "$OLD_VERSION" == "9.9.0" || "$OLD_VERSION" == "9.10.0" ]] || fail "Expected Music Vault 9.9.0; found '${OLD_VERSION:-unknown}'. No changes were made."
[[ -s "$APP_ROOT/app.py" && -s "$APP_ROOT/templates/index.html" && -s "$APP_ROOT/data/musicvault.db" && -d "$APP_ROOT/static" ]] || fail "Existing Music Vault application/database files were not found."
for file in install-update.sh payload/remove_v98_owner_profile.py payload/mv101-profile-chooser.js payload/mv101-profile-chooser.css tests/test_profile_restore.py SHA256SUMS_9_10_0.txt; do
  [[ -s "$PKG_DIR/$file" ]] || fail "Package file is missing: $file"
done

(cd "$PKG_DIR" && sha256sum -c SHA256SUMS_9_10_0.txt)
python3 "$PKG_DIR/tests/test_profile_restore.py"
python3 -m py_compile "$PKG_DIR/payload/remove_v98_owner_profile.py"
node --check "$PKG_DIR/payload/mv101-profile-chooser.js"
bash -n "$PKG_DIR/install-update.sh"

mkdir -p "$BACKUP/templates" "$BACKUP/data" "$BACKUP/static"
cp -a "$APP_ROOT/app.py" "$BACKUP/app.py"
cp -a "$APP_ROOT/templates/index.html" "$BACKUP/templates/index.html"
cp -a "$APP_ROOT/data/installed_version.txt" "$BACKUP/data/installed_version.txt" 2>/dev/null && HAD_VERSION=1 || true
if [[ -f "$APP_ROOT/data/.session-secret" ]]; then HAD_SECRET=1; cp -a "$APP_ROOT/data/.session-secret" "$BACKUP/data/.session-secret"; fi
if [[ -f "$APP_ROOT/mv98_accounts.py" ]]; then HAD_MODULE=1; cp -a "$APP_ROOT/mv98_accounts.py" "$BACKUP/mv98_accounts.py"; fi
if [[ -f "$APP_ROOT/static/mv98-auth.js" ]]; then HAD_AUTH_JS=1; cp -a "$APP_ROOT/static/mv98-auth.js" "$BACKUP/mv98-auth.js"; fi
if [[ -f "$APP_ROOT/static/mv98-auth.css" ]]; then HAD_AUTH_CSS=1; cp -a "$APP_ROOT/static/mv98-auth.css" "$BACKUP/mv98-auth.css"; fi
if [[ -f "$APP_ROOT/static/mv101-profile-chooser.js" ]]; then HAD_PICKER_JS=1; cp -a "$APP_ROOT/static/mv101-profile-chooser.js" "$BACKUP/mv101-profile-chooser.js"; fi
if [[ -f "$APP_ROOT/static/mv101-profile-chooser.css" ]]; then HAD_PICKER_CSS=1; cp -a "$APP_ROOT/static/mv101-profile-chooser.css" "$BACKUP/mv101-profile-chooser.css"; fi
python3 - "$APP_ROOT/data/musicvault.db" "$BACKUP/data/musicvault.db" <<'PY'
import sqlite3,sys
src=sqlite3.connect(sys.argv[1],timeout=30)
dst=sqlite3.connect(sys.argv[2])
try:
    src.backup(dst)
finally:
    dst.close()
    src.close()
PY
chmod 0600 "$BACKUP/data/musicvault.db"

TMP="$APP_ROOT/.mv101-stage-$STAMP"
mkdir -p "$TMP/templates" "$TMP/static"
cp -a "$APP_ROOT/templates/index.html" "$TMP/templates/index.html"
cp -a "$PKG_DIR/payload/mv101-profile-chooser.js" "$TMP/static/mv101-profile-chooser.js"
cp -a "$PKG_DIR/payload/mv101-profile-chooser.css" "$TMP/static/mv101-profile-chooser.css"
python3 - "$TMP/templates/index.html" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1])
html=p.read_text(encoding="utf-8")
css='<link rel="stylesheet" href="/static/mv101-profile-chooser.css?v=9.10.0">'
js='<script defer src="/static/mv101-profile-chooser.js?v=9.10.0"></script>'
if "mv98-auth" in html or "mv98-auth-pending" in html:
    raise SystemExit("Secure sign-in references unexpectedly remain in the template.")
if css not in html:
    if "</head>" not in html: raise SystemExit("Template head insertion point is missing.")
    html=html.replace("</head>",css+"\n</head>",1)
if js not in html:
    if "</body>" not in html: raise SystemExit("Template body insertion point is missing.")
    html=html.replace("</body>",js+"\n</body>",1)
if html.count(css)!=1 or html.count(js)!=1:
    raise SystemExit("Profile chooser assets were not added exactly once.")
p.write_text(html,encoding="utf-8")
print("PASS: profile chooser assets staged without replacing the existing player/template.")
PY

ROLLBACK_ACTIVE=1
systemctl stop "$SERVICE"
python3 "$PKG_DIR/payload/remove_v98_owner_profile.py" "$APP_ROOT/data/musicvault.db"
rm -f "$APP_ROOT/data/.session-secret" "$APP_ROOT/data/.session-secret.tmp"
rm -f "$APP_ROOT/mv98_accounts.py" "$APP_ROOT/static/mv98-auth.js" "$APP_ROOT/static/mv98-auth.css"
install -o "$OWNER" -g "$GROUP" -m 0644 "$TMP/templates/index.html" "$APP_ROOT/templates/index.html"
install -o "$OWNER" -g "$GROUP" -m 0644 "$TMP/static/mv101-profile-chooser.js" "$APP_ROOT/static/mv101-profile-chooser.js"
install -o "$OWNER" -g "$GROUP" -m 0644 "$TMP/static/mv101-profile-chooser.css" "$APP_ROOT/static/mv101-profile-chooser.css"
printf '9.10.0\n' > "$APP_ROOT/data/installed_version.txt"
chown "$OWNER:$GROUP" "$APP_ROOT/templates/index.html" "$APP_ROOT/static/mv101-profile-chooser.js" "$APP_ROOT/static/mv101-profile-chooser.css" "$APP_ROOT/data/installed_version.txt"
chmod 0644 "$APP_ROOT/data/installed_version.txt"
rm -rf "$TMP"

systemctl restart "$SERVICE"
READY=0
for attempt in $(seq 1 35); do
  if curl --silent --show-error --fail --max-time 4 "http://127.0.0.1:$PORT/" -o /tmp/mv101-home.html 2>/dev/null &&
     curl --silent --show-error --fail --max-time 4 "http://127.0.0.1:$PORT/api/status" -o /tmp/mv101-status.json 2>/dev/null &&
     curl --silent --show-error --fail --max-time 4 "http://127.0.0.1:$PORT/api/family" -o /tmp/mv101-family.json 2>/dev/null; then
    READY=1
    break
  fi
  sleep 2
done
[[ "$READY" == "1" ]] || fail "Music Vault did not pass its home, status, and family-profile health checks."
systemctl is-active --quiet "$SERVICE" || fail "Music Vault service is not active."
python3 - /tmp/mv101-family.json <<'PY'
import json,sys
data=json.load(open(sys.argv[1],encoding="utf-8"))
members=data.get("members") or []
names=[str(x.get("name","")) for x in members]
if len(names)!=2 or any(n.casefold()=="owner" for n in names):
    raise SystemExit("Family profile validation failed: expected the two original profiles and no Owner profile; got "+repr(names))
print("PASS: exactly two family profiles remain: "+", ".join(names))
PY
for path in "static/mv101-profile-chooser.js?v=9.10.0" "static/mv101-profile-chooser.css?v=9.10.0"; do
  curl --silent --show-error --fail --max-time 8 "http://127.0.0.1:$PORT/$path" -o /dev/null
done
if grep -Eq 'mv98-auth|mv98-auth-pending|Secure Sign In' /tmp/mv101-home.html; then
  fail "Secure sign-in markup was detected after update."
fi
[[ ! -e "$APP_ROOT/mv98_accounts.py" && ! -e "$APP_ROOT/static/mv98-auth.js" && ! -e "$APP_ROOT/static/mv98-auth.css" ]] || fail "A 9.8 sign-in file remains installed."
[[ ! -e "$APP_ROOT/data/.session-secret" ]] || fail "A 9.8 account session secret remains installed."

ROLLBACK_ACTIVE=0
trap - ERR
echo
echo "============================================================"
echo " MUSIC VAULT 9.10.0 — FAMILY PROFILE PICKER"
echo "============================================================"
echo "Extra synthetic Owner profile: REMOVED"
echo "Original family profiles: 2 — VERIFIED"
echo "Password accounts and 9.8 session secret: REMOVED"
echo "Who's Listening layout: refreshed, responsive, one-tap selection"
echo "Add Person: existing no-password profile action preserved"
echo "Legacy profiles, playlists, favorites, history and tracks: PRESERVED"
echo "Playback, background playback and EQ: unchanged"
echo "Music files: untouched"
echo "Database/source snapshot: $BACKUP"
echo "============================================================"
