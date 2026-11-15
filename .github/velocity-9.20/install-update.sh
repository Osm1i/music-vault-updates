#!/usr/bin/env bash
set -Eeuo pipefail
APP_ROOT="${MUSICVAULT_HOME:-/opt/music-vault}"
SERVICE="${MUSICVAULT_SERVICE:-music-vault.service}"
PORT="${MUSICVAULT_PORT:-8788}"
PKG_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$APP_ROOT/backups/vanguard-9.20.0-android-touch-$STAMP"
OWNER="$(stat -c '%U' "$APP_ROOT" 2>/dev/null || echo root)"
GROUP="$(stat -c '%G' "$APP_ROOT" 2>/dev/null || echo root)"
ROLLBACK_ACTIVE=0
HAD_CSS=0
HAD_VERSION=0
STEP='initializing'
log(){ printf '[Music Vault 9.20.0] %s\n' "$*"; }
fail(){ log "ERROR at $STEP: $*" >&2; return 1; }
wait_http(){
  local attempt
  for attempt in $(seq 1 30); do
    if systemctl is-active --quiet "$SERVICE" && curl -fsS --max-time 3 "http://127.0.0.1:$PORT/" -o /tmp/mv920-health.html; then return 0; fi
    sleep 1
  done
  return 1
}
rollback(){
  local status=$?
  if [[ "$ROLLBACK_ACTIVE" == 1 ]]; then
    trap rollback ERR; set +e
    log "Failure at $STEP; restoring backed-up app files."
    [[ -f "$BACKUP/templates/index.html" ]] && cp -a "$BACKUP/templates/index.html" "$APP_ROOT/templates/index.html"
    if [[ "$HAD_CSS" == 1 && -f "$BACKUP/static/mv920-android-touch.css" ]]; then
      cp -a "$BACKUP/static/mv920-android-touch.css" "$APP_ROOT/static/mv920-android-touch.css"
    else
      rm -f "$APP_ROOT/static/mv920-android-touch.css"
    fi
    if [[ "$HAD_VERSION" == 1 && -f "$BACKUP/data/installed_version.txt" ]]; then
      cp -a "$BACKUP/data/installed_version.txt" "$APP_ROOT/data/installed_version.txt"
    else
      rm -f "$APP_ROOT/data/installed_version.txt"
    fi
    chown "$OWNER:$GROUP" "$APP_ROOT/templates/index.html" 2>/dev/null || true
    [[ ! -f "$APP_ROOT/static/mv920-android-touch.css" ]] || chown "$OWNER:$GROUP" "$APP_ROOT/static/mv920-android-touch.css" 2>/dev/null || true
    log 'Restarting restored app to clear Flask template cache.'
    systemctl restart "$SERVICE" || true
    wait_http || log 'WARNING: files were restored, but service health did not recover automatically.'
    log "Rollback finished. Database, profiles, playlists, queue, EQ, player JS, service worker and music files were not modified. Backup: $BACKUP"
  fi
  exit "$status"
}
trap rollback ERR

STEP='package and app layout validation'
log 'Step 1/7: validating package and Music Vault layout'
[[ "$(id -u)" == 0 ]] || fail 'Run installer as root.'
[[ -s "$APP_ROOT/app.py" && -s "$APP_ROOT/templates/index.html" && -d "$APP_ROOT/static" && -d "$APP_ROOT/data" ]] || fail 'Music Vault app layout not found; no files changed.'
for file in install-update.sh patch_android_touch.py mv920-android-touch.css tests/test_android_touch.py SHA256SUMS_9_20_0.txt MUSIC_VAULT_RELEASE_VERSION.txt; do
  [[ -s "$PKG_DIR/$file" ]] || fail "Package file missing: $file"
done
(cd "$PKG_DIR" && sha256sum -c SHA256SUMS_9_20_0.txt)
[[ "$(tr -d '\r\n' < "$PKG_DIR/MUSIC_VAULT_RELEASE_VERSION.txt")" == 9.20.0 ]] || fail 'Package version marker mismatch.'

STEP='package regression tests'
log 'Step 2/7: running package regression tests'
python3 -m py_compile "$PKG_DIR/patch_android_touch.py" "$PKG_DIR/tests/test_android_touch.py"
python3 "$PKG_DIR/tests/test_android_touch.py"
bash -n "$PKG_DIR/install-update.sh"

STEP='pre-update service health'
log 'Step 3/7: confirming service and home page before update'
systemctl is-active --quiet "$SERVICE" || fail 'Music Vault service is not active; no files changed.'
curl -fsS --max-time 8 "http://127.0.0.1:$PORT/" -o /tmp/mv920-before.html || fail 'Music Vault home page did not respond; no files changed.'

STEP='backups'
log 'Step 4/7: backing up template, touch stylesheet and version marker'
mkdir -p "$BACKUP/templates" "$BACKUP/static" "$BACKUP/data"
cp -a "$APP_ROOT/templates/index.html" "$BACKUP/templates/index.html"
if [[ -f "$APP_ROOT/static/mv920-android-touch.css" ]]; then HAD_CSS=1; cp -a "$APP_ROOT/static/mv920-android-touch.css" "$BACKUP/static/mv920-android-touch.css"; fi
if [[ -f "$APP_ROOT/data/installed_version.txt" ]]; then HAD_VERSION=1; cp -a "$APP_ROOT/data/installed_version.txt" "$BACKUP/data/installed_version.txt"; fi

STEP='Android viewport and touch patch'
log 'Step 5/7: applying responsive viewport and Android touch patch; player JS and service worker remain untouched'
ROLLBACK_ACTIVE=1
python3 "$PKG_DIR/patch_android_touch.py" "$APP_ROOT"
chown "$OWNER:$GROUP" "$APP_ROOT/templates/index.html" "$APP_ROOT/static/mv920-android-touch.css"

STEP='Flask template cache refresh'
log 'Step 6/7: restarting Music Vault to refresh Flask/Jinja template cache'
systemctl restart "$SERVICE"
wait_http || fail 'Music Vault did not return healthy within 30 seconds; rolling back.'

STEP='live HTML/CSS verification'
log 'Step 7/7: verifying live responsive viewport, detector and stylesheet'
curl -fsS --max-time 8 "http://127.0.0.1:$PORT/" -o /tmp/mv920-live.html
curl -fsS --max-time 8 "http://127.0.0.1:$PORT/static/mv920-android-touch.css?v=9.20.0" -o /tmp/mv920-live.css
python3 - "$APP_ROOT" <<'PY'
from pathlib import Path
import sys
root=Path(sys.argv[1])
h=(root/'templates/index.html').read_text(encoding='utf-8')
c=(root/'static/mv920-android-touch.css').read_text(encoding='utf-8')
assert h.count('mv920-viewport') == 1, 'responsive viewport not uniquely registered'
assert 'width=device-width, initial-scale=1, viewport-fit=cover' in h, 'responsive viewport content missing'
assert h.count('mv920-android-touch-css') == 1, 'stylesheet link not uniquely registered'
assert h.count('mv920-android-touch-detect') == 1, 'Android detector not uniquely registered'
assert 'touch-action: pan-x pan-y pinch-zoom !important' in c, 'root touch gestures missing'
assert 'touch-action: auto !important' in c, 'child touch behavior reset missing'
PY
grep -q 'mv920-viewport' /tmp/mv920-live.html || fail 'Live HTML does not contain responsive viewport.'
grep -q 'mv920-android-touch-css' /tmp/mv920-live.html || fail 'Live HTML does not contain new stylesheet link.'
grep -q 'mv920-android-touch-detect' /tmp/mv920-live.html || fail 'Live HTML does not contain Android detector.'
cmp -s "$APP_ROOT/static/mv920-android-touch.css" /tmp/mv920-live.css || fail 'Served stylesheet differs from installed file.'
[[ "$(systemctl is-active "$SERVICE")" == active ]] || fail 'Music Vault service is not active after update.'
printf '9.20.0\n' > "$APP_ROOT/data/installed_version.txt"
chown "$OWNER:$GROUP" "$APP_ROOT/data/installed_version.txt"
ROLLBACK_ACTIVE=0
trap - ERR
log 'SUCCESS: 9.20.0 installed; responsive viewport and Android touch CSS passed live checks.'
log 'Database, profiles, playlists, queue, EQ, player JavaScript, service worker and music files were not modified.'
log "Backup: $BACKUP"
