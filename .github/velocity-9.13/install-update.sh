#!/usr/bin/env bash
set -Eeuo pipefail
APP_ROOT="${MUSICVAULT_HOME:-/opt/music-vault}"
SERVICE="${MUSICVAULT_SERVICE:-music-vault.service}"
PORT="${MUSICVAULT_PORT:-8788}"
PKG_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$APP_ROOT/backups/vanguard-9.13.0-single-profile-screen-$STAMP"
OWNER="$(stat -c '%U' "$APP_ROOT" 2>/dev/null || echo root)"
GROUP="$(stat -c '%G' "$APP_ROOT" 2>/dev/null || echo root)"
OLD_VERSION="$(cat "$APP_ROOT/data/installed_version.txt" 2>/dev/null || true)"
ROLLBACK_ACTIVE=0
HAD_VERSION=0
HAD_12_JS=0
HAD_12_CSS=0
HAD_13_JS=0
HAD_13_CSS=0

fail(){ echo "ERROR: $*" >&2; return 1; }
rollback(){
 local status=$?
 if [[ "$ROLLBACK_ACTIVE" == "1" ]]; then
  trap - ERR
  set +e
  echo "ERROR: v9.13 failed health checks. Restoring the previous profile screen." >&2
  systemctl stop "$SERVICE" 2>/dev/null || true
  [[ -f "$BACKUP/templates/index.html" ]] && cp -a "$BACKUP/templates/index.html" "$APP_ROOT/templates/index.html"
  if [[ "$HAD_VERSION" == "1" && -f "$BACKUP/data/installed_version.txt" ]]; then cp -a "$BACKUP/data/installed_version.txt" "$APP_ROOT/data/installed_version.txt"; else printf '%s\n' "$OLD_VERSION" > "$APP_ROOT/data/installed_version.txt"; fi
  if [[ "$HAD_12_JS" == "1" && -f "$BACKUP/static/mv112-profile-studio.js" ]]; then cp -a "$BACKUP/static/mv112-profile-studio.js" "$APP_ROOT/static/mv112-profile-studio.js"; fi
  if [[ "$HAD_12_CSS" == "1" && -f "$BACKUP/static/mv112-profile-studio.css" ]]; then cp -a "$BACKUP/static/mv112-profile-studio.css" "$APP_ROOT/static/mv112-profile-studio.css"; fi
  if [[ "$HAD_13_JS" == "1" && -f "$BACKUP/static/mv113-profile-studio.js" ]]; then cp -a "$BACKUP/static/mv113-profile-studio.js" "$APP_ROOT/static/mv113-profile-studio.js"; else rm -f "$APP_ROOT/static/mv113-profile-studio.js"; fi
  if [[ "$HAD_13_CSS" == "1" && -f "$BACKUP/static/mv113-profile-studio.css" ]]; then cp -a "$BACKUP/static/mv113-profile-studio.css" "$APP_ROOT/static/mv113-profile-studio.css"; else rm -f "$APP_ROOT/static/mv113-profile-studio.css"; fi
  chown "$OWNER:$GROUP" "$APP_ROOT/templates/index.html" "$APP_ROOT/data/installed_version.txt" 2>/dev/null || true
  systemctl restart "$SERVICE"
  echo "Rollback completed. Database and music files were never modified. Snapshot: $BACKUP" >&2
 fi
 exit "$status"
}
trap rollback ERR

[[ "$(id -u)" == "0" ]] || fail "Run through Music Vault's root-owned update installer."
[[ "$OLD_VERSION" == "9.12.0" || "$OLD_VERSION" == "9.13.0" ]] || fail "Expected installed version 9.12.0; found '${OLD_VERSION:-unknown}'. No changes made."
[[ -s "$APP_ROOT/app.py" && -s "$APP_ROOT/templates/index.html" && -s "$APP_ROOT/data/musicvault.db" && -d "$APP_ROOT/static" ]] || fail "Existing Music Vault app files are missing."
for file in install-update.sh payload/mv113-profile-studio.js payload/mv113-profile-studio.css tests/test_single_profile_screen.py SHA256SUMS_9_13_0.txt; do [[ -s "$PKG_DIR/$file" ]] || fail "Missing release file: $file"; done

(cd "$PKG_DIR" && sha256sum -c SHA256SUMS_9_13_0.txt)
python3 "$PKG_DIR/tests/test_single_profile_screen.py"
node --check "$PKG_DIR/payload/mv113-profile-studio.js"
bash -n "$PKG_DIR/install-update.sh"

mkdir -p "$BACKUP/templates" "$BACKUP/data" "$BACKUP/static"
cp -a "$APP_ROOT/templates/index.html" "$BACKUP/templates/index.html"
if [[ -f "$APP_ROOT/data/installed_version.txt" ]]; then HAD_VERSION=1; cp -a "$APP_ROOT/data/installed_version.txt" "$BACKUP/data/installed_version.txt"; fi
for pair in "mv112-profile-studio.js:HAD_12_JS" "mv112-profile-studio.css:HAD_12_CSS" "mv113-profile-studio.js:HAD_13_JS" "mv113-profile-studio.css:HAD_13_CSS"; do
 file="${pair%%:*}"; flag="${pair##*:}"
 if [[ -f "$APP_ROOT/static/$file" ]]; then printf -v "$flag" '1'; cp -a "$APP_ROOT/static/$file" "$BACKUP/static/$file"; fi
done
# Snapshot only; no SQLite writes/migrations are performed by this UI-only update.
python3 - "$APP_ROOT/data/musicvault.db" "$BACKUP/data/musicvault.db" <<'PY'
import sqlite3,sys
src=sqlite3.connect(sys.argv[1],timeout=30);dst=sqlite3.connect(sys.argv[2])
try:src.backup(dst)
finally:dst.close();src.close()
PY
chmod 0600 "$BACKUP/data/musicvault.db"

TMP="$APP_ROOT/.mv113-stage-$STAMP"
mkdir -p "$TMP/static"
cp -a "$PKG_DIR/payload/mv113-profile-studio.js" "$TMP/static/mv113-profile-studio.js"
cp -a "$PKG_DIR/payload/mv113-profile-studio.css" "$TMP/static/mv113-profile-studio.css"
python3 - "$APP_ROOT/templates/index.html" "$TMP/index.html" <<'PY'
from pathlib import Path
import re,sys
source=Path(sys.argv[1]).read_text(encoding="utf-8")
# Remove all previous profile experiment assets, so only v9.13 runs.
for token in (
 "mv101-profile-chooser.css","mv101-profile-chooser.js",
 "mv111-profile-studio.css","mv111-profile-studio.js",
 "mv112-profile-studio.css","mv112-profile-studio.js"
):
 source=re.sub(r'<(?:link|script)\b[^>]*'+re.escape(token)+r'[^>]*>\s*','',source,flags=re.I)
css='<link rel="stylesheet" href="/static/mv113-profile-studio.css?v=9.13.0">'
js='<script defer src="/static/mv113-profile-studio.js?v=9.13.0"></script>'
if css not in source:
 if '</head>' not in source:raise SystemExit("Template </head> was not found.")
 source=source.replace('</head>',css+'\n</head>',1)
if js not in source:
 if '</body>' not in source:raise SystemExit("Template </body> was not found.")
 source=source.replace('</body>',js+'\n</body>',1)
if source.count(css)!=1 or source.count(js)!=1:raise SystemExit("v9.13 assets are duplicated or missing.")
Path(sys.argv[2]).write_text(source,encoding="utf-8")
print("PASS: index references one profile renderer only.")
PY

ROLLBACK_ACTIVE=1
systemctl stop "$SERVICE"
install -o "$OWNER" -g "$GROUP" -m 0644 "$TMP/index.html" "$APP_ROOT/templates/index.html"
install -o "$OWNER" -g "$GROUP" -m 0644 "$TMP/static/mv113-profile-studio.js" "$APP_ROOT/static/mv113-profile-studio.js"
install -o "$OWNER" -g "$GROUP" -m 0644 "$TMP/static/mv113-profile-studio.css" "$APP_ROOT/static/mv113-profile-studio.css"
rm -f "$APP_ROOT/static/mv112-profile-studio.js" "$APP_ROOT/static/mv112-profile-studio.css"
rm -f "$APP_ROOT/static/mv111-profile-studio.js" "$APP_ROOT/static/mv111-profile-studio.css"
rm -f "$APP_ROOT/static/mv101-profile-chooser.js" "$APP_ROOT/static/mv101-profile-chooser.css"
printf '9.13.0\n' > "$APP_ROOT/data/installed_version.txt"
chown "$OWNER:$GROUP" "$APP_ROOT/templates/index.html" "$APP_ROOT/static/mv113-profile-studio.js" "$APP_ROOT/static/mv113-profile-studio.css" "$APP_ROOT/data/installed_version.txt"
chmod 0644 "$APP_ROOT/data/installed_version.txt"
rm -rf "$TMP"

systemctl restart "$SERVICE"
READY=0
for attempt in $(seq 1 35); do
 if curl --silent --show-error --fail --max-time 4 "http://127.0.0.1:$PORT/" -o /tmp/mv113-home.html 2>/dev/null &&
    curl --silent --show-error --fail --max-time 4 "http://127.0.0.1:$PORT/api/status" -o /tmp/mv113-status.json 2>/dev/null &&
    curl --silent --show-error --fail --max-time 4 "http://127.0.0.1:$PORT/api/family" -o /tmp/mv113-family.json 2>/dev/null; then READY=1;break;fi
 sleep 2
done
[[ "$READY" == "1" ]] || fail "Home, status, or family API health check failed."
systemctl is-active --quiet "$SERVICE" || fail "Music Vault service is not active."
python3 - /tmp/mv113-family.json <<'PY'
import json,sys
d=json.load(open(sys.argv[1],encoding="utf-8"))
m=d.get("members")
if not isinstance(m,list) or not m or any(not str(x.get("name","")).strip() for x in m):raise SystemExit("Family profile API returned invalid data.")
print("PASS: "+str(len(m))+" existing family profile(s) still available.")
PY
for path in "static/mv113-profile-studio.js?v=9.13.0" "static/mv113-profile-studio.css?v=9.13.0";do curl --silent --show-error --fail --max-time 8 "http://127.0.0.1:$PORT/$path" -o /dev/null;done
grep -q 'mv113-profile-studio.css?v=9.13.0' /tmp/mv113-home.html
grep -q 'mv113-profile-studio.js?v=9.13.0' /tmp/mv113-home.html
! grep -q 'mv112-profile-studio' /tmp/mv113-home.html
[[ "$(cat "$APP_ROOT/data/installed_version.txt")" == "9.13.0" ]] || fail "Version marker check failed."

ROLLBACK_ACTIVE=0
trap - ERR
echo
echo "============================================================"
echo " MUSIC VAULT 9.13.0 — ONE PROFILE SCREEN"
echo "============================================================"
echo "Original profile veil: hidden while the new chooser is active"
echo "One visible Who's Listening screen: VERIFIED"
echo "Profile selection: existing native profile-card click handler"
echo "Forced API reload after selection: REMOVED"
echo "Add/Edit: original forms/actions reused"
echo "Startup intro: untouched"
echo "Backend, database, music, library, playlists, player, EQ: untouched"
echo "Home/status/family/static asset checks: PASSED"
echo "Backup: $BACKUP"
echo "============================================================"
