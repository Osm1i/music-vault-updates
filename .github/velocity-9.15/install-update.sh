#!/usr/bin/env bash
set -Eeuo pipefail
APP_ROOT="${MUSICVAULT_HOME:-/opt/music-vault}"
SERVICE="${MUSICVAULT_SERVICE:-music-vault.service}"
PORT="${MUSICVAULT_PORT:-8788}"
PKG_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$APP_ROOT/backups/vanguard-9.15.0-bottom-island-$STAMP"
OWNER="$(stat -c '%U' "$APP_ROOT" 2>/dev/null || echo root)"
GROUP="$(stat -c '%G' "$APP_ROOT" 2>/dev/null || echo root)"
OLD_VERSION="$(cat "$APP_ROOT/data/installed_version.txt" 2>/dev/null || true)"
ROLLBACK_ACTIVE=0
fail(){ echo "ERROR: $*" >&2; return 1; }
rollback(){
 local status=$?
 if [[ "$ROLLBACK_ACTIVE" == "1" ]]; then
  trap - ERR
  set +e
  echo "ERROR: 9.15.0 validation failed. Restoring the previous UI assets and version marker." >&2
  for rel in templates/index.html static/mv-consolidated.css static/mv-consolidated.js static/sw.js data/installed_version.txt; do
   [[ -f "$BACKUP/$rel" ]] && cp -a "$BACKUP/$rel" "$APP_ROOT/$rel"
  done
  chown "$OWNER:$GROUP" "$APP_ROOT/templates/index.html" "$APP_ROOT/static/mv-consolidated.css" "$APP_ROOT/static/mv-consolidated.js" "$APP_ROOT/static/sw.js" "$APP_ROOT/data/installed_version.txt" 2>/dev/null || true
  echo "Rollback completed. Existing database and music were never modified. Backup: $BACKUP" >&2
 fi
 exit "$status"
}
trap rollback ERR

[[ "$(id -u)" == "0" ]] || fail "Run through Music Vault's root-owned update installer."
[[ "$OLD_VERSION" == "9.14.0" ]] || fail "Expected Music Vault 9.14.0; found '${OLD_VERSION:-unknown}'. No changes made."
[[ -s "$APP_ROOT/app.py" && -s "$APP_ROOT/templates/index.html" && -s "$APP_ROOT/data/musicvault.db" && -d "$APP_ROOT/static" ]] || fail "Existing Music Vault installation files are missing."
for file in install-update.sh patch_island_position.py tests/test_island_position.py SHA256SUMS_9_15_0.txt MUSIC_VAULT_RELEASE_VERSION.txt; do
 [[ -s "$PKG_DIR/$file" ]] || fail "Package file missing: $file"
done
(cd "$PKG_DIR" && sha256sum -c SHA256SUMS_9_15_0.txt)
python3 -m py_compile "$PKG_DIR/patch_island_position.py" "$PKG_DIR/tests/test_island_position.py"
python3 "$PKG_DIR/tests/test_island_position.py"
bash -n "$PKG_DIR/install-update.sh"
[[ "$(tr -d '\r\n' < "$PKG_DIR/MUSIC_VAULT_RELEASE_VERSION.txt")" == "9.15.0" ]] || fail "Package version marker is invalid."
systemctl is-active --quiet "$SERVICE" || fail "Music Vault service is not active; no files changed."
curl --silent --show-error --fail --max-time 5 "http://127.0.0.1:$PORT/" -o /tmp/mv915-before-home.html || fail "Music Vault home check failed before update."

mkdir -p "$BACKUP/templates" "$BACKUP/static" "$BACKUP/data"
for rel in templates/index.html static/mv-consolidated.css static/mv-consolidated.js static/sw.js data/installed_version.txt; do
 [[ -s "$APP_ROOT/$rel" ]] || fail "Required file is missing: $APP_ROOT/$rel"
 mkdir -p "$BACKUP/$(dirname "$rel")"
 cp -a "$APP_ROOT/$rel" "$BACKUP/$rel"
done
# Consistent SQLite recovery snapshot; the live database itself is read only.
python3 - "$APP_ROOT/data/musicvault.db" "$BACKUP/data/musicvault.db" <<'PY'
import sqlite3,sys
src=sqlite3.connect(sys.argv[1],timeout=30); dst=sqlite3.connect(sys.argv[2])
try: src.backup(dst)
finally: dst.close(); src.close()
PY
chmod 0600 "$BACKUP/data/musicvault.db"

ROLLBACK_ACTIVE=1
python3 "$PKG_DIR/patch_island_position.py" "$APP_ROOT"
chown "$OWNER:$GROUP" "$APP_ROOT/templates/index.html" "$APP_ROOT/static/mv-consolidated.css" "$APP_ROOT/static/mv-consolidated.js" "$APP_ROOT/static/sw.js" "$APP_ROOT/data/installed_version.txt"
chmod 0644 "$APP_ROOT/data/installed_version.txt"

# Validate what clients will actually receive. No restart, so playback is not interrupted.
curl --silent --show-error --fail --max-time 5 "http://127.0.0.1:$PORT/" -o /tmp/mv915-home.html
curl --silent --show-error --fail --max-time 5 "http://127.0.0.1:$PORT/static/mv-consolidated.css?v=9.15.0" -o /tmp/mv915.css
curl --silent --show-error --fail --max-time 5 "http://127.0.0.1:$PORT/static/mv-consolidated.js?v=9.15.0" -o /tmp/mv915.js
curl --silent --show-error --fail --max-time 5 "http://127.0.0.1:$PORT/static/sw.js" -o /tmp/mv915-sw.js
grep -q '"/static/mv-consolidated.css?v=9.15.0' /tmp/mv915-home.html
grep -q '"/static/mv-consolidated.js?v=9.15.0' /tmp/mv915-home.html
grep -q 'safe-area-inset-bottom,0px) + 0px' /tmp/mv915.css
grep -q "safe-area-inset-bottom, 0px) + 0px" /tmp/mv915.js
grep -q 'music-vault-shell-v9-15-0-island-position-v1' /tmp/mv915-sw.js
[[ "$(cat "$APP_ROOT/data/installed_version.txt")" == "9.15.0" ]] || fail "Installed version marker did not update."
systemctl is-active --quiet "$SERVICE" || fail "Music Vault service is not active after the update."
ROLLBACK_ACTIVE=0
trap - ERR

echo
echo "============================================================"
echo " MUSIC VAULT 9.15.0 — BOTTOM ISLAND POSITION FIX"
echo "============================================================"
echo "Bottom Island: moved down 8px while retaining iPhone safe-area clearance"
echo "CSS and JavaScript position controllers: aligned"
echo "Asset and service-worker caches: refreshed"
echo "Playback, EQ, navigation actions and library data: untouched"
echo "Service restart: NOT REQUIRED; playback was not interrupted"
echo "Home / CSS / JavaScript / service-worker checks: PASSED"
echo "Backup: $BACKUP"
echo "============================================================"
