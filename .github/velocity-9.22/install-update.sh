#!/usr/bin/env bash
set -Eeuo pipefail
APP_ROOT="${MUSICVAULT_HOME:-/opt/music-vault}"
SERVICE="${MUSICVAULT_SERVICE:-music-vault.service}"
PORT="${MUSICVAULT_PORT:-8788}"
PKG_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$APP_ROOT/backups/vanguard-9.22.0-android-touch-$STAMP"
OWNER="$(stat -c '%U' "$APP_ROOT" 2>/dev/null || echo root)"
GROUP="$(stat -c '%G' "$APP_ROOT" 2>/dev/null || echo root)"
ROLLBACK_ACTIVE=0
HAD_CSS=0
HAD_VERSION=0
STEP='initializing'

log(){ printf '[Music Vault 9.22.0] %s\n' "$*"; }
fail(){ log "ERROR at $STEP: $*" >&2; return 1; }
wait_http(){
  local attempt
  for attempt in $(seq 1 30); do
    if systemctl is-active --quiet "$SERVICE" &&
       curl -fsS --max-time 3 "http://127.0.0.1:$PORT/" -o /tmp/mv922-health.html; then
      return 0
    fi
    sleep 1
  done
  return 1
}
rollback(){
  local status=$?
  if [[ "$ROLLBACK_ACTIVE" == 1 ]]; then
    trap rollback ERR
    set +e
    log "Failure at $STEP; restoring backed-up app files."
    [[ -f "$BACKUP/templates/index.html" ]] &&
      cp -a "$BACKUP/templates/index.html" "$APP_ROOT/templates/index.html"
    if [[ "$HAD_CSS" == 1 && -f "$BACKUP/static/mv922-android-touch.css" ]]; then
      cp -a "$BACKUP/static/mv922-android-touch.css" "$APP_ROOT/static/mv922-android-touch.css"
    else
      rm -f "$APP_ROOT/static/mv922-android-touch.css"
    fi
    if [[ "$HAD_VERSION" == 1 && -f "$BACKUP/data/installed_version.txt" ]]; then
      cp -a "$BACKUP/data/installed_version.txt" "$APP_ROOT/data/installed_version.txt"
    else
      rm -f "$APP_ROOT/data/installed_version.txt"
    fi
    chown "$OWNER:$GROUP" "$APP_ROOT/templates/index.html" 2>/dev/null || true
    [[ ! -f "$APP_ROOT/static/mv922-android-touch.css" ]] ||
      chown "$OWNER:$GROUP" "$APP_ROOT/static/mv922-android-touch.css" 2>/dev/null || true
    log "Restarting restored app to clear Flask template cache."
    systemctl restart "$SERVICE" || true
    wait_http || log "WARNING: files were restored, but service health did not recover automatically."
    log "Rollback finished. Playback JavaScript, service worker, database, profiles, playlists, queue, EQ and music files were not modified. Backup: $BACKUP"
  fi
  exit "$status"
}
trap rollback ERR

STEP='package and app layout validation'
log 'Step 1/7: validating package and Music Vault layout'
[[ "$(id -u)" == 0 ]] || fail 'Run installer as root.'
[[ -s "$APP_ROOT/app.py" && -s "$APP_ROOT/templates/index.html" && -d "$APP_ROOT/static" && -d "$APP_ROOT/data" ]] ||
  fail 'Music Vault app layout not found; no files changed.'
for file in install-update.sh patch_android_touch.py mv922-android-touch.css tests/test_android_touch.py SHA256SUMS_9_22_0.txt MUSIC_VAULT_RELEASE_VERSION.txt; do
  [[ -s "$PKG_DIR/$file" ]] || fail "Package file missing: $file"
done
(cd "$PKG_DIR" && sha256sum -c SHA256SUMS_9_22_0.txt)
[[ "$(tr -d '\r\n' < "$PKG_DIR/MUSIC_VAULT_RELEASE_VERSION.txt")" == 9.22.0 ]] ||
  fail 'Package version marker mismatch.'

STEP='package regression tests'
log 'Step 2/7: running package regression tests'
python3 -m py_compile "$PKG_DIR/patch_android_touch.py" "$PKG_DIR/tests/test_android_touch.py"
python3 "$PKG_DIR/tests/test_android_touch.py"
bash -n "$PKG_DIR/install-update.sh"

STEP='pre-update service health'
log 'Step 3/7: confirming service and home page before update'
systemctl is-active --quiet "$SERVICE" || fail 'Music Vault service is not active; no files changed.'
curl -fsS --max-time 8 "http://127.0.0.1:$PORT/" -o /tmp/mv922-before.html ||
  fail 'Music Vault home page did not respond; no files changed.'

STEP='backups'
log 'Step 4/7: backing up template, new touch stylesheet and version marker'
mkdir -p "$BACKUP/templates" "$BACKUP/static" "$BACKUP/data"
cp -a "$APP_ROOT/templates/index.html" "$BACKUP/templates/index.html"
if [[ -f "$APP_ROOT/static/mv922-android-touch.css" ]]; then
  HAD_CSS=1
  cp -a "$APP_ROOT/static/mv922-android-touch.css" "$BACKUP/static/mv922-android-touch.css"
fi
if [[ -f "$APP_ROOT/data/installed_version.txt" ]]; then
  HAD_VERSION=1
  cp -a "$APP_ROOT/data/installed_version.txt" "$BACKUP/data/installed_version.txt"
fi

STEP='Android touch and scroll recovery'
log 'Step 5/7: installing Android-only touch recovery; player JS and service worker stay untouched'
ROLLBACK_ACTIVE=1
python3 "$PKG_DIR/patch_android_touch.py" "$APP_ROOT"
chown "$OWNER:$GROUP" "$APP_ROOT/templates/index.html" "$APP_ROOT/static/mv922-android-touch.css"

STEP='Flask template cache refresh'
log 'Step 6/7: restarting Music Vault to refresh Flask/Jinja template cache'
systemctl restart "$SERVICE"
wait_http || fail 'Music Vault did not return healthy within 30 seconds; rolling back.'

STEP='live HTML/CSS verification'
log 'Step 7/7: verifying live responsive viewport, Android recovery hook, stylesheet and service health'
curl -fsS --max-time 8 "http://127.0.0.1:$PORT/" -o /tmp/mv922-live.html
curl -fsS --max-time 8 "http://127.0.0.1:$PORT/static/mv922-android-touch.css?v=9.22.0" -o /tmp/mv922-live.css
python3 - "$APP_ROOT" <<'PY'
from pathlib import Path
import sys
root = Path(sys.argv[1])
html = (root / "templates/index.html").read_text(encoding="utf-8")
css = (root / "static/mv922-android-touch.css").read_text(encoding="utf-8")
assert html.count("mv922-viewport") == 1
assert 'width=device-width, initial-scale=1, viewport-fit=cover' in html
assert html.count("mv922-android-touch-css") == 1
assert html.count("mv922-android-touch-recovery") == 1
assert "touch-action: pan-x pan-y pinch-zoom !important" in css
assert "overflow-y: auto !important" in css
assert "overscroll-behavior-y: auto !important" in css
PY
grep -q 'mv922-viewport' /tmp/mv922-live.html || fail 'Live HTML does not contain responsive viewport.'
grep -q 'mv922-android-touch-css' /tmp/mv922-live.html || fail 'Live HTML does not contain recovery stylesheet link.'
grep -q 'mv922-android-touch-recovery' /tmp/mv922-live.html || fail 'Live HTML does not contain recovery hook.'
cmp -s "$APP_ROOT/static/mv922-android-touch.css" /tmp/mv922-live.css ||
  fail 'Served stylesheet differs from installed file.'
[[ "$(systemctl is-active "$SERVICE")" == active ]] || fail 'Music Vault service is not active after update.'
printf '9.22.0\n' > "$APP_ROOT/data/installed_version.txt"
chown "$OWNER:$GROUP" "$APP_ROOT/data/installed_version.txt"
ROLLBACK_ACTIVE=0
trap - ERR
log 'SUCCESS: 9.22.0 installed; Android touch/scroll assets passed live HTML/CSS and service checks.'
log 'Playback JavaScript, service worker, database, profiles, playlists, queue, EQ and music files were not modified.'
log "Backup: $BACKUP"
