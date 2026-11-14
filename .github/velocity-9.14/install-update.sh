#!/usr/bin/env bash
set -Eeuo pipefail
APP_ROOT="\${MUSICVAULT_HOME:-/opt/music-vault}"
SERVICE="\${MUSICVAULT_SERVICE:-music-vault.service}"
PORT="\${MUSICVAULT_PORT:-8788}"
PKG_DIR="$(cd -- "$(dirname -- "\${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$APP_ROOT/backups/vanguard-9.14.0-profile-recovery-$STAMP"
OWNER="$(stat -c '%U' "$APP_ROOT" 2>/dev/null || echo root)"
GROUP="$(stat -c '%G' "$APP_ROOT" 2>/dev/null || echo root)"
OLD_VERSION="$(cat "$APP_ROOT/data/installed_version.txt" 2>/dev/null || true)"
ROLLBACK_ACTIVE=0
HAD_VERSION=0
fail(){ echo "ERROR: $*" >&2; return 1; }
rollback(){
 local status=$?
 if [[ "$ROLLBACK_ACTIVE" == "1" ]]; then
  trap - ERR
  set +e
  echo "ERROR: recovery failed. Restoring the previous index template and version marker." >&2
  systemctl stop "$SERVICE" 2>/dev/null || true
  [[ -f "$BACKUP/templates/index.html" ]] && cp -a "$BACKUP/templates/index.html" "$APP_ROOT/templates/index.html"
  if [[ "$HAD_VERSION" == "1" && -f "$BACKUP/data/installed_version.txt" ]]; then cp -a "$BACKUP/data/installed_version.txt" "$APP_ROOT/data/installed_version.txt"; else printf '%s\n' "$OLD_VERSION" > "$APP_ROOT/data/installed_version.txt"; fi
  for file in mv101-profile-chooser.js mv101-profile-chooser.css mv111-profile-studio.js mv111-profile-studio.css mv112-profile-studio.js mv112-profile-studio.css mv113-profile-studio.js mv113-profile-studio.css; do
   [[ -f "$BACKUP/static/$file" ]] && cp -a "$BACKUP/static/$file" "$APP_ROOT/static/$file"
  done
  chown "$OWNER:$GROUP" "$APP_ROOT/templates/index.html" "$APP_ROOT/data/installed_version.txt" 2>/dev/null || true
  systemctl restart "$SERVICE"
  echo "Rollback completed. Database and music were never modified. Backup: $BACKUP" >&2
 fi
 exit "$status"
}
trap rollback ERR

[[ "$(id -u)" == "0" ]] || fail "Run through Music Vault's root-owned update installer."
case "$OLD_VERSION" in 9.12.0|9.13.0|9.14.0) ;; *) fail "Expected 9.12.0 or 9.13.0; found '\${OLD_VERSION:-unknown}'. No changes made." ;; esac
[[ -s "$APP_ROOT/app.py" && -s "$APP_ROOT/templates/index.html" && -s "$APP_ROOT/data/musicvault.db" && -d "$APP_ROOT/static" ]] || fail "Existing Music Vault installation files are missing."
for file in install-update.sh tests/test_profile_recovery.py SHA256SUMS_9_14_0.txt MUSIC_VAULT_RELEASE_VERSION.txt; do [[ -s "$PKG_DIR/$file" ]] || fail "Package file missing: $file"; done
(cd "$PKG_DIR" && sha256sum -c SHA256SUMS_9_14_0.txt)
python3 "$PKG_DIR/tests/test_profile_recovery.py"
bash -n "$PKG_DIR/install-update.sh"

mkdir -p "$BACKUP/templates" "$BACKUP/data" "$BACKUP/static"
cp -a "$APP_ROOT/templates/index.html" "$BACKUP/templates/index.html"
if [[ -f "$APP_ROOT/data/installed_version.txt" ]]; then HAD_VERSION=1; cp -a "$APP_ROOT/data/installed_version.txt" "$BACKUP/data/installed_version.txt"; fi
for file in mv101-profile-chooser.js mv101-profile-chooser.css mv111-profile-studio.js mv111-profile-studio.css mv112-profile-studio.js mv112-profile-studio.css mv113-profile-studio.js mv113-profile-studio.css; do
 if [[ -f "$APP_ROOT/static/$file" ]]; then cp -a "$APP_ROOT/static/$file" "$BACKUP/static/$file"; fi
done
python3 - "$APP_ROOT/data/musicvault.db" "$BACKUP/data/musicvault.db" <<'PY'
import sqlite3,sys
src=sqlite3.connect(sys.argv[1],timeout=30);dst=sqlite3.connect(sys.argv[2])
try: src.backup(dst)
finally: dst.close();src.close()
PY
chmod 0600 "$BACKUP/data/musicvault.db"

TMP="$APP_ROOT/.mv114-stage-$STAMP"
mkdir -p "$TMP"
python3 - "$APP_ROOT/templates/index.html" "$TMP/index.html" <<'PY'
from pathlib import Path
import re,sys
source=Path(sys.argv[1]).read_text(encoding="utf-8")
tokens=("mv101-profile-chooser.css","mv101-profile-chooser.js","mv111-profile-studio.css","mv111-profile-studio.js","mv112-profile-studio.css","mv112-profile-studio.js","mv113-profile-studio.css","mv113-profile-studio.js")
for token in tokens:
 source=re.sub(r'<(?:link|script)\b[^>]*'+re.escape(token)+r'[^>]*>\s*','',source,flags=re.I)
for token in tokens:
 if token in source: raise SystemExit("Broken chooser reference remains: "+token)
Path(sys.argv[2]).write_text(source,encoding="utf-8")
print("PASS: all injected chooser references removed; original selector and intro markup preserved.")
PY

ROLLBACK_ACTIVE=1
systemctl stop "$SERVICE"
install -o "$OWNER" -g "$GROUP" -m 0644 "$TMP/index.html" "$APP_ROOT/templates/index.html"
rm -f "$APP_ROOT/static/mv101-profile-chooser.js" "$APP_ROOT/static/mv101-profile-chooser.css" \
 "$APP_ROOT/static/mv111-profile-studio.js" "$APP_ROOT/static/mv111-profile-studio.css" \
 "$APP_ROOT/static/mv112-profile-studio.js" "$APP_ROOT/static/mv112-profile-studio.css" \
 "$APP_ROOT/static/mv113-profile-studio.js" "$APP_ROOT/static/mv113-profile-studio.css"
printf '9.14.0\n' > "$APP_ROOT/data/installed_version.txt"
chown "$OWNER:$GROUP" "$APP_ROOT/templates/index.html" "$APP_ROOT/data/installed_version.txt"
chmod 0644 "$APP_ROOT/data/installed_version.txt"
rm -rf "$TMP"

systemctl restart "$SERVICE"
READY=0
for attempt in $(seq 1 35); do
 if curl --silent --show-error --fail --max-time 4 "http://127.0.0.1:$PORT/" -o /tmp/mv114-home.html 2>/dev/null &&
    curl --silent --show-error --fail --max-time 4 "http://127.0.0.1:$PORT/api/status" -o /tmp/mv114-status.json 2>/dev/null &&
    curl --silent --show-error --fail --max-time 4 "http://127.0.0.1:$PORT/api/family" -o /tmp/mv114-family.json 2>/dev/null; then READY=1; break; fi
 sleep 2
done
[[ "$READY" == "1" ]] || fail "Music Vault home, status, or family API health check failed."
systemctl is-active --quiet "$SERVICE" || fail "Music Vault service is not active."
python3 - /tmp/mv114-family.json <<'PY'
import json,sys
data=json.load(open(sys.argv[1],encoding="utf-8")); members=data.get("members")
if not isinstance(members,list) or not members or any(not str(m.get("name","")).strip() for m in members): raise SystemExit("Family API did not return valid profiles.")
print("PASS: "+str(len(members))+" existing family profile(s) remain.")
PY
for token in mv101-profile-chooser mv111-profile-studio mv112-profile-studio mv113-profile-studio; do if grep -q "$token" /tmp/mv114-home.html; then fail "Broken chooser reference remains in home HTML: $token"; fi; done
[[ "$(cat "$APP_ROOT/data/installed_version.txt")" == "9.14.0" ]] || fail "Version marker did not update."
for file in mv101-profile-chooser.js mv101-profile-chooser.css mv111-profile-studio.js mv111-profile-studio.css mv112-profile-studio.js mv112-profile-studio.css mv113-profile-studio.js mv113-profile-studio.css; do [[ ! -e "$APP_ROOT/static/$file" ]] || fail "Stale chooser asset remains: $file"; done

ROLLBACK_ACTIVE=0
trap - ERR
echo
echo "============================================================"
echo " MUSIC VAULT 9.14.0 — PROFILE SCREEN RECOVERY"
echo "============================================================"
echo "Injected v9.10-v9.13 chooser assets: REMOVED"
echo "Original native profile selector: RESTORED"
echo "Startup intro / Enter Your Vault: UNCHANGED"
echo "Existing family profiles: VERIFIED"
echo "Database, playlists, favorites, history, tracks: UNTOUCHED"
echo "Music files, playback, background playback, EQ: UNTOUCHED"
echo "Home/status/family API health checks: PASSED"
echo "Backup: $BACKUP"
echo "============================================================"
