#!/usr/bin/env bash
set -Eeuo pipefail

APP_ROOT="${MUSICVAULT_HOME:-/opt/music-vault}"
SERVICE="${MUSICVAULT_SERVICE:-music-vault.service}"
PORT="${MUSICVAULT_PORT:-8788}"
PKG_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$APP_ROOT/backups/vanguard-9.11.0-profile-studio-$STAMP"
OWNER="$(stat -c '%U' "$APP_ROOT" 2>/dev/null || echo root)"
GROUP="$(stat -c '%G' "$APP_ROOT" 2>/dev/null || echo root)"
OLD_VERSION="$(cat "$APP_ROOT/data/installed_version.txt" 2>/dev/null || true)"
ROLLBACK_ACTIVE=0
HAD_VERSION=0
HAD_OLD_JS=0
HAD_OLD_CSS=0
HAD_NEW_JS=0
HAD_NEW_CSS=0

fail() { echo "ERROR: $*" >&2; return 1; }

rollback() {
  local status=$?
  if [[ "$ROLLBACK_ACTIVE" == "1" ]]; then
    trap - ERR
    set +e
    echo "ERROR: 9.11.0 did not pass health checks. Restoring the previous chooser..." >&2
    systemctl stop "$SERVICE" 2>/dev/null || true
    [[ -f "$BACKUP/templates/index.html" ]] && cp -a "$BACKUP/templates/index.html" "$APP_ROOT/templates/index.html"
    if [[ "$HAD_VERSION" == "1" && -f "$BACKUP/data/installed_version.txt" ]]; then
      cp -a "$BACKUP/data/installed_version.txt" "$APP_ROOT/data/installed_version.txt"
    else
      printf '%s\n' "$OLD_VERSION" > "$APP_ROOT/data/installed_version.txt"
    fi
    if [[ "$HAD_OLD_JS" == "1" && -f "$BACKUP/static/mv101-profile-chooser.js" ]]; then cp -a "$BACKUP/static/mv101-profile-chooser.js" "$APP_ROOT/static/mv101-profile-chooser.js"; fi
    if [[ "$HAD_OLD_CSS" == "1" && -f "$BACKUP/static/mv101-profile-chooser.css" ]]; then cp -a "$BACKUP/static/mv101-profile-chooser.css" "$APP_ROOT/static/mv101-profile-chooser.css"; fi
    if [[ "$HAD_NEW_JS" == "1" && -f "$BACKUP/static/mv111-profile-studio.js" ]]; then cp -a "$BACKUP/static/mv111-profile-studio.js" "$APP_ROOT/static/mv111-profile-studio.js"; else rm -f "$APP_ROOT/static/mv111-profile-studio.js"; fi
    if [[ "$HAD_NEW_CSS" == "1" && -f "$BACKUP/static/mv111-profile-studio.css" ]]; then cp -a "$BACKUP/static/mv111-profile-studio.css" "$APP_ROOT/static/mv111-profile-studio.css"; else rm -f "$APP_ROOT/static/mv111-profile-studio.css"; fi
    chown "$OWNER:$GROUP" "$APP_ROOT/templates/index.html" "$APP_ROOT/data/installed_version.txt" 2>/dev/null || true
    systemctl restart "$SERVICE"
    echo "Rollback completed. The database was never modified. Snapshot: $BACKUP" >&2
  fi
  exit "$status"
}
trap rollback ERR

[[ "$(id -u)" == "0" ]] || fail "Run through Music Vault's root-owned update install service."
[[ "$OLD_VERSION" == "9.10.0" || "$OLD_VERSION" == "9.11.0" ]] || fail "Expected Music Vault 9.10.0; found '${OLD_VERSION:-unknown}'. No files were changed."
[[ -s "$APP_ROOT/templates/index.html" && -s "$APP_ROOT/app.py" && -s "$APP_ROOT/data/musicvault.db" && -d "$APP_ROOT/static" ]] || fail "Existing Music Vault app, template, database, or static folder is missing."
for file in install-update.sh payload/mv111-profile-studio.js payload/mv111-profile-studio.css tests/test_profile_studio.py SHA256SUMS_9_11_0.txt; do
  [[ -s "$PKG_DIR/$file" ]] || fail "Package file is missing: $file"
done

(cd "$PKG_DIR" && sha256sum -c SHA256SUMS_9_11_0.txt)
python3 "$PKG_DIR/tests/test_profile_studio.py"
node --check "$PKG_DIR/payload/mv111-profile-studio.js"
bash -n "$PKG_DIR/install-update.sh"

mkdir -p "$BACKUP/templates" "$BACKUP/data" "$BACKUP/static"
cp -a "$APP_ROOT/templates/index.html" "$BACKUP/templates/index.html"
if [[ -f "$APP_ROOT/data/installed_version.txt" ]]; then
  HAD_VERSION=1
  cp -a "$APP_ROOT/data/installed_version.txt" "$BACKUP/data/installed_version.txt"
fi
for pair in "mv101-profile-chooser.js:HAD_OLD_JS" "mv101-profile-chooser.css:HAD_OLD_CSS" "mv111-profile-studio.js:HAD_NEW_JS" "mv111-profile-studio.css:HAD_NEW_CSS"; do
  file="${pair%%:*}"; flag="${pair##*:}"
  if [[ -f "$APP_ROOT/static/$file" ]]; then
    printf -v "$flag" '1'
    cp -a "$APP_ROOT/static/$file" "$BACKUP/static/$file"
  fi
done
# Database snapshot only: this update does not run migrations or write to SQLite.
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

TMP="$APP_ROOT/.mv111-stage-$STAMP"
mkdir -p "$TMP/static"
cp -a "$PKG_DIR/payload/mv111-profile-studio.js" "$TMP/static/mv111-profile-studio.js"
cp -a "$PKG_DIR/payload/mv111-profile-studio.css" "$TMP/static/mv111-profile-studio.css"
python3 - "$APP_ROOT/templates/index.html" "$TMP/index.html" <<'PY'
from pathlib import Path
import re,sys
source=Path(sys.argv[1]).read_text(encoding="utf-8")
# Retire only the immediately preceding chooser's asset references.
source=re.sub(r'<link\b[^>]*mv101-profile-chooser\.css[^>]*>\s*', '', source, flags=re.I)
source=re.sub(r'<script\b[^>]*mv101-profile-chooser\.js[^>]*></script>\s*', '', source, flags=re.I)
css='<link rel="stylesheet" href="/static/mv111-profile-studio.css?v=9.11.0">'
js='<script defer src="/static/mv111-profile-studio.js?v=9.11.0"></script>'
if css not in source:
    if '</head>' not in source: raise SystemExit("Template head insertion point is missing.")
    source=source.replace('</head>',css+'\n</head>',1)
if js not in source:
    if '</body>' not in source: raise SystemExit("Template body insertion point is missing.")
    source=source.replace('</body>',js+'\n</body>',1)
if source.count(css)!=1 or source.count(js)!=1:
    raise SystemExit("Profile Studio assets were not added exactly once.")
if 'mv98-auth' in source or 'mv98-auth-pending' in source:
    raise SystemExit("Unexpected old password sign-in markup found; refusing to alter the template.")
Path(sys.argv[2]).write_text(source,encoding="utf-8")
print("PASS: staged Profile Studio assets; existing Music Vault profile handlers/template remain in place.")
PY

ROLLBACK_ACTIVE=1
systemctl stop "$SERVICE"
install -o "$OWNER" -g "$GROUP" -m 0644 "$TMP/index.html" "$APP_ROOT/templates/index.html"
install -o "$OWNER" -g "$GROUP" -m 0644 "$TMP/static/mv111-profile-studio.js" "$APP_ROOT/static/mv111-profile-studio.js"
install -o "$OWNER" -g "$GROUP" -m 0644 "$TMP/static/mv111-profile-studio.css" "$APP_ROOT/static/mv111-profile-studio.css"
rm -rf "$APP_ROOT/static/mv101-profile-chooser.js" "$APP_ROOT/static/mv101-profile-chooser.css"
printf '9.11.0\n' > "$APP_ROOT/data/installed_version.txt"
chown "$OWNER:$GROUP" "$APP_ROOT/templates/index.html" "$APP_ROOT/static/mv111-profile-studio.js" "$APP_ROOT/static/mv111-profile-studio.css" "$APP_ROOT/data/installed_version.txt"
chmod 0644 "$APP_ROOT/data/installed_version.txt"
rm -rf "$TMP"

systemctl restart "$SERVICE"
READY=0
for attempt in $(seq 1 35); do
  if curl --silent --show-error --fail --max-time 4 "http://127.0.0.1:$PORT/" -o /tmp/mv111-home.html 2>/dev/null &&
     curl --silent --show-error --fail --max-time 4 "http://127.0.0.1:$PORT/api/status" -o /tmp/mv111-status.json 2>/dev/null &&
     curl --silent --show-error --fail --max-time 4 "http://127.0.0.1:$PORT/api/family" -o /tmp/mv111-family.json 2>/dev/null; then
    READY=1
    break
  fi
  sleep 2
done
[[ "$READY" == "1" ]] || fail "Music Vault failed its home, status, or family-profile health check."
systemctl is-active --quiet "$SERVICE" || fail "Music Vault service is not active."
python3 - /tmp/mv111-family.json <<'PY'
import json,sys
data=json.load(open(sys.argv[1],encoding="utf-8"))
members=data.get("members")
if not isinstance(members,list) or not members or any(not str(x.get("name","")).strip() for x in members):
    raise SystemExit("Existing family profile API did not return a valid profile list.")
print("PASS: existing family profile API returned "+str(len(members))+" profile(s).")
PY
for path in "static/mv111-profile-studio.js?v=9.11.0" "static/mv111-profile-studio.css?v=9.11.0"; do
  curl --silent --show-error --fail --max-time 8 "http://127.0.0.1:$PORT/$path" -o /dev/null
done
grep -q 'mv111-profile-studio.css?v=9.11.0' /tmp/mv111-home.html
grep -q 'mv111-profile-studio.js?v=9.11.0' /tmp/mv111-home.html
! grep -q 'mv101-profile-chooser' /tmp/mv111-home.html
[[ -e "$APP_ROOT/static/mv111-profile-studio.js" && -e "$APP_ROOT/static/mv111-profile-studio.css" ]] || fail "New Profile Studio assets are missing."
[[ "$(cat "$APP_ROOT/data/installed_version.txt")" == "9.11.0" ]] || fail "Installed version marker was not updated."
ROLLBACK_ACTIVE=0
trap - ERR

echo
echo "============================================================"
echo " MUSIC VAULT 9.11.0 — PROFILE STUDIO"
echo "============================================================"
echo "Profile selector: redesigned, compact responsive grid"
echo "Profile selection and Add Profile handlers: unchanged"
echo "Edit profile actions: preserved"
echo "Password/account features: none added"
echo "Backend and database: untouched"
echo "Library, playlists, favorites, player, background playback and EQ: untouched"
echo "API and asset health checks: PASSED"
echo "Database/source snapshot: $BACKUP"
echo "============================================================"
