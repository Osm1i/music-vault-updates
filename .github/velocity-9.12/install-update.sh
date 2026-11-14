#!/usr/bin/env bash
set -Eeuo pipefail
APP_ROOT="${MUSICVAULT_HOME:-/opt/music-vault}"
SERVICE="${MUSICVAULT_SERVICE:-music-vault.service}"
PORT="${MUSICVAULT_PORT:-8788}"
PKG_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$APP_ROOT/backups/vanguard-9.12.0-profile-overhaul-$STAMP"
OWNER="$(stat -c '%U' "$APP_ROOT" 2>/dev/null || echo root)"
GROUP="$(stat -c '%G' "$APP_ROOT" 2>/dev/null || echo root)"
OLD_VERSION="$(cat "$APP_ROOT/data/installed_version.txt" 2>/dev/null || true)"
ROLLBACK_ACTIVE=0
HAD_VERSION=0
HAD_STUDIO_JS=0
HAD_STUDIO_CSS=0
HAD_OLD_JS=0
HAD_OLD_CSS=0

fail(){ echo "ERROR: $*" >&2; return 1; }
rollback(){
 local status=$?
 if [[ "$ROLLBACK_ACTIVE" == "1" ]]; then
  trap - ERR
  set +e
  echo "ERROR: 9.12.0 failed health checks. Restoring previous Who's Listening screen..." >&2
  systemctl stop "$SERVICE" 2>/dev/null || true
  [[ -f "$BACKUP/templates/index.html" ]] && cp -a "$BACKUP/templates/index.html" "$APP_ROOT/templates/index.html"
  if [[ "$HAD_VERSION" == "1" && -f "$BACKUP/data/installed_version.txt" ]]; then cp -a "$BACKUP/data/installed_version.txt" "$APP_ROOT/data/installed_version.txt"; else printf '%s\n' "$OLD_VERSION" > "$APP_ROOT/data/installed_version.txt"; fi
  if [[ "$HAD_STUDIO_JS" == "1" && -f "$BACKUP/static/mv112-profile-studio.js" ]]; then cp -a "$BACKUP/static/mv112-profile-studio.js" "$APP_ROOT/static/mv112-profile-studio.js"; else rm -f "$APP_ROOT/static/mv112-profile-studio.js"; fi
  if [[ "$HAD_STUDIO_CSS" == "1" && -f "$BACKUP/static/mv112-profile-studio.css" ]]; then cp -a "$BACKUP/static/mv112-profile-studio.css" "$APP_ROOT/static/mv112-profile-studio.css"; else rm -f "$APP_ROOT/static/mv112-profile-studio.css"; fi
  if [[ "$HAD_OLD_JS" == "1" && -f "$BACKUP/static/mv111-profile-studio.js" ]]; then cp -a "$BACKUP/static/mv111-profile-studio.js" "$APP_ROOT/static/mv111-profile-studio.js"; fi
  if [[ "$HAD_OLD_CSS" == "1" && -f "$BACKUP/static/mv111-profile-studio.css" ]]; then cp -a "$BACKUP/static/mv111-profile-studio.css" "$APP_ROOT/static/mv111-profile-studio.css"; fi
  chown "$OWNER:$GROUP" "$APP_ROOT/templates/index.html" "$APP_ROOT/data/installed_version.txt" 2>/dev/null || true
  systemctl restart "$SERVICE"
  echo "Rollback completed. Source/database snapshot retained at $BACKUP; no data tables were changed." >&2
 fi
 exit "$status"
}
trap rollback ERR

[[ "$(id -u)" == "0" ]] || fail "Run via Music Vault's root-owned update installer."
[[ "$OLD_VERSION" == "9.11.0" || "$OLD_VERSION" == "9.12.0" ]] || fail "Expected installed version 9.11.0; found '${OLD_VERSION:-unknown}'. No changes made."
[[ -s "$APP_ROOT/app.py" && -s "$APP_ROOT/templates/index.html" && -s "$APP_ROOT/data/musicvault.db" && -d "$APP_ROOT/static" ]] || fail "Existing Music Vault files are missing."
for file in install-update.sh payload/mv112-profile-studio.js payload/mv112-profile-studio.css tests/test_profile_overhaul.py SHA256SUMS_9_12_0.txt; do [[ -s "$PKG_DIR/$file" ]] || fail "Missing package file: $file"; done

(cd "$PKG_DIR" && sha256sum -c SHA256SUMS_9_12_0.txt)
python3 "$PKG_DIR/tests/test_profile_overhaul.py"
node --check "$PKG_DIR/payload/mv112-profile-studio.js"
bash -n "$PKG_DIR/install-update.sh"

mkdir -p "$BACKUP/templates" "$BACKUP/data" "$BACKUP/static"
cp -a "$APP_ROOT/templates/index.html" "$BACKUP/templates/index.html"
if [[ -f "$APP_ROOT/data/installed_version.txt" ]]; then HAD_VERSION=1; cp -a "$APP_ROOT/data/installed_version.txt" "$BACKUP/data/installed_version.txt"; fi
for pair in "mv112-profile-studio.js:HAD_STUDIO_JS" "mv112-profile-studio.css:HAD_STUDIO_CSS" "mv111-profile-studio.js:HAD_OLD_JS" "mv111-profile-studio.css:HAD_OLD_CSS"; do
 file="${pair%%:*}"; flag="${pair##*:}"
 if [[ -f "$APP_ROOT/static/$file" ]]; then printf -v "$flag" '1'; cp -a "$APP_ROOT/static/$file" "$BACKUP/static/$file"; fi
done
python3 - "$APP_ROOT/data/musicvault.db" "$BACKUP/data/musicvault.db" <<'PY'
import sqlite3,sys
src=sqlite3.connect(sys.argv[1],timeout=30)
dst=sqlite3.connect(sys.argv[2])
try: src.backup(dst)
finally: dst.close(); src.close()
PY
chmod 0600 "$BACKUP/data/musicvault.db"

TMP="$APP_ROOT/.mv112-stage-$STAMP"
mkdir -p "$TMP/static"
cp -a "$PKG_DIR/payload/mv112-profile-studio.js" "$TMP/static/mv112-profile-studio.js"
cp -a "$PKG_DIR/payload/mv112-profile-studio.css" "$TMP/static/mv112-profile-studio.css"
python3 - "$APP_ROOT/templates/index.html" "$TMP/index.html" <<'PY'
from pathlib import Path
import re,sys
source=Path(sys.argv[1]).read_text(encoding="utf-8")
# Remove older guessed overlay experiments and their CSS/JS, then reference only the
# real v9.12 self-contained picker. No original page markup or route code is replaced.
for token in ("mv101-profile-chooser.css","mv101-profile-chooser.js","mv111-profile-studio.css","mv111-profile-studio.js"):
    source=re.sub(r'<(?:link|script)\b[^>]*'+re.escape(token)+r'[^>]*>\s*','',source,flags=re.I)
css='<link rel="stylesheet" href="/static/mv112-profile-studio.css?v=9.12.0">'
js='<script defer src="/static/mv112-profile-studio.js?v=9.12.0"></script>'
if css not in source:
    if '</head>' not in source: raise SystemExit("Template </head> insertion point missing.")
    source=source.replace('</head>',css+'\n</head>',1)
if js not in source:
    if '</body>' not in source: raise SystemExit("Template </body> insertion point missing.")
    source=source.replace('</body>',js+'\n</body>',1)
if source.count(css)!=1 or source.count(js)!=1:
    raise SystemExit("v9.12 Profile Studio assets were not linked exactly once.")
Path(sys.argv[2]).write_text(source,encoding="utf-8")
print("PASS: template references only the new v9.12 self-contained picker.")
PY

ROLLBACK_ACTIVE=1
systemctl stop "$SERVICE"
install -o "$OWNER" -g "$GROUP" -m 0644 "$TMP/index.html" "$APP_ROOT/templates/index.html"
install -o "$OWNER" -g "$GROUP" -m 0644 "$TMP/static/mv112-profile-studio.js" "$APP_ROOT/static/mv112-profile-studio.js"
install -o "$OWNER" -g "$GROUP" -m 0644 "$TMP/static/mv112-profile-studio.css" "$APP_ROOT/static/mv112-profile-studio.css"
rm -f "$APP_ROOT/static/mv101-profile-chooser.js" "$APP_ROOT/static/mv101-profile-chooser.css" "$APP_ROOT/static/mv111-profile-studio.js" "$APP_ROOT/static/mv111-profile-studio.css"
printf '9.12.0\n' > "$APP_ROOT/data/installed_version.txt"
chown "$OWNER:$GROUP" "$APP_ROOT/templates/index.html" "$APP_ROOT/static/mv112-profile-studio.js" "$APP_ROOT/static/mv112-profile-studio.css" "$APP_ROOT/data/installed_version.txt"
chmod 0644 "$APP_ROOT/data/installed_version.txt"
rm -rf "$TMP"

systemctl restart "$SERVICE"
READY=0
for attempt in $(seq 1 35); do
 if curl --silent --show-error --fail --max-time 4 "http://127.0.0.1:$PORT/" -o /tmp/mv112-home.html 2>/dev/null &&
    curl --silent --show-error --fail --max-time 4 "http://127.0.0.1:$PORT/api/status" -o /tmp/mv112-status.json 2>/dev/null &&
    curl --silent --show-error --fail --max-time 4 "http://127.0.0.1:$PORT/api/family" -o /tmp/mv112-family.json 2>/dev/null; then READY=1; break; fi
 sleep 2
done
[[ "$READY" == "1" ]] || fail "Music Vault home/status/family API health checks failed."
systemctl is-active --quiet "$SERVICE" || fail "Music Vault service is not active."
python3 - /tmp/mv112-family.json <<'PY'
import json,sys
data=json.load(open(sys.argv[1],encoding="utf-8"))
names=[str(m.get("name","")).strip() for m in data.get("members",[])]
if not names or any(not n for n in names): raise SystemExit("Family profiles are malformed.")
print("PASS: existing family API supplies "+str(len(names))+" profile(s): "+", ".join(names))
PY
for path in "static/mv112-profile-studio.js?v=9.12.0" "static/mv112-profile-studio.css?v=9.12.0"; do curl --silent --show-error --fail --max-time 8 "http://127.0.0.1:$PORT/$path" -o /dev/null; done
grep -q 'mv112-profile-studio.css?v=9.12.0' /tmp/mv112-home.html
grep -q 'mv112-profile-studio.js?v=9.12.0' /tmp/mv112-home.html
! grep -q 'mv111-profile-studio' /tmp/mv112-home.html
[[ "$(cat "$APP_ROOT/data/installed_version.txt")" == "9.12.0" ]] || fail "Installed version marker was not updated."

ROLLBACK_ACTIVE=0
trap - ERR
echo
echo "============================================================"
echo " MUSIC VAULT 9.12.0 — WHO'S LISTENING OVERHAUL"
echo "============================================================"
echo "New full-screen profile picker: INSTALLED"
echo "Profiles loaded from existing /api/family API"
echo "Selection uses existing /api/profile/active API"
echo "Edit and Add actions reuse existing controls"
echo "Password/PIN/account registration: none"
echo "App backend, database, library, player, background playback and EQ: untouched"
echo "Home, status, family API, static asset checks: PASSED"
echo "Backup: $BACKUP"
echo "============================================================"
