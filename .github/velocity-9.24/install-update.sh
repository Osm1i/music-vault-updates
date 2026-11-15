#!/usr/bin/env bash
set -Eeuo pipefail
APP_ROOT="\${MUSICVAULT_HOME:-/opt/music-vault}"
SERVICE="\${MUSICVAULT_SERVICE:-music-vault.service}"
PORT="\${MUSICVAULT_PORT:-8788}"
PKG_DIR="$(cd -- "$(dirname -- "\${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$APP_ROOT/backups/vanguard-9.24.0-home-downloads-$STAMP"
OWNER="$(stat -c '%U' "$APP_ROOT" 2>/dev/null || echo root)"
GROUP="$(stat -c '%G' "$APP_ROOT" 2>/dev/null || echo root)"
ROLLBACK_ACTIVE=0
HAD_JS=0
HAD_CSS=0
HAD_VERSION=0
STEP='initializing'

log(){ printf '[Music Vault 9.24.0] %s\n' "$*"; }
fail(){ log "ERROR at $STEP: $*" >&2; return 1; }
wait_http(){
  local attempt
  for attempt in $(seq 1 30); do
    if systemctl is-active --quiet "$SERVICE" &&
       curl -fsS --max-time 3 "http://127.0.0.1:$PORT/" -o /tmp/mv924-health.html; then
      return 0
    fi
    sleep 1
  done
  return 1
}
rollback(){
  local status=$?
  if [[ "$ROLLBACK_ACTIVE" == 1 ]]; then
    trap - ERR
    set +e
    log "Failure at $STEP; restoring the backed-up app files."
    [[ -f "$BACKUP/app.py" ]] && cp -a "$BACKUP/app.py" "$APP_ROOT/app.py"
    [[ -f "$BACKUP/templates/index.html" ]] && cp -a "$BACKUP/templates/index.html" "$APP_ROOT/templates/index.html"
    if [[ "$HAD_JS" == 1 && -f "$BACKUP/static/mv924-home-repair.js" ]]; then
      cp -a "$BACKUP/static/mv924-home-repair.js" "$APP_ROOT/static/mv924-home-repair.js"
    else
      rm -f "$APP_ROOT/static/mv924-home-repair.js"
    fi
    if [[ "$HAD_CSS" == 1 && -f "$BACKUP/static/mv924-home-repair.css" ]]; then
      cp -a "$BACKUP/static/mv924-home-repair.css" "$APP_ROOT/static/mv924-home-repair.css"
    else
      rm -f "$APP_ROOT/static/mv924-home-repair.css"
    fi
    if [[ "$HAD_VERSION" == 1 && -f "$BACKUP/data/installed_version.txt" ]]; then
      cp -a "$BACKUP/data/installed_version.txt" "$APP_ROOT/data/installed_version.txt"
    else
      rm -f "$APP_ROOT/data/installed_version.txt"
    fi
    chown "$OWNER:$GROUP" "$APP_ROOT/app.py" "$APP_ROOT/templates/index.html" 2>/dev/null || true
    [[ ! -f "$APP_ROOT/static/mv924-home-repair.js" ]] || chown "$OWNER:$GROUP" "$APP_ROOT/static/mv924-home-repair.js" 2>/dev/null || true
    [[ ! -f "$APP_ROOT/static/mv924-home-repair.css" ]] || chown "$OWNER:$GROUP" "$APP_ROOT/static/mv924-home-repair.css" 2>/dev/null || true
    log 'Restarting restored Music Vault to refresh Flask/Jinja.'
    systemctl restart "$SERVICE" || true
    wait_http || log 'WARNING: files were restored, but service health did not recover automatically.'
    log "Rollback finished. Database, music files, profiles, playlists, Favorites, history, existing playback bundle, service worker, queue and EQ were not modified. Backup: $BACKUP"
  fi
  exit "$status"
}
trap rollback ERR

STEP='package and app layout validation'
log 'Step 1/7: validating package and Music Vault layout'
[[ "$(id -u)" == 0 ]] || fail 'Run installer as root.'
[[ -s "$APP_ROOT/app.py" && -s "$APP_ROOT/templates/index.html" && -d "$APP_ROOT/static" && -d "$APP_ROOT/data" ]] ||
  fail 'Music Vault app layout not found; no files changed.'
for file in install-update.sh patch_home_downloads.py mv924-home-repair.js mv924-home-repair.css tests/test_home_downloads.py SHA256SUMS_9_24_0.txt MUSIC_VAULT_RELEASE_VERSION.txt; do
  [[ -s "$PKG_DIR/$file" ]] || fail "Package file missing: $file"
done
(cd "$PKG_DIR" && sha256sum -c SHA256SUMS_9_24_0.txt)
[[ "$(tr -d '\r\n' < "$PKG_DIR/MUSIC_VAULT_RELEASE_VERSION.txt")" == 9.24.0 ]] || fail 'Package version marker mismatch.'

STEP='package regression tests'
log 'Step 2/7: running package regression tests'
python3 -m py_compile "$PKG_DIR/patch_home_downloads.py" "$PKG_DIR/tests/test_home_downloads.py"
python3 "$PKG_DIR/tests/test_home_downloads.py"
node --check "$PKG_DIR/mv924-home-repair.js"
bash -n "$PKG_DIR/install-update.sh"

STEP='pre-update service health'
log 'Step 3/7: confirming service and home page before update'
systemctl is-active --quiet "$SERVICE" || fail 'Music Vault service is not active; no files changed.'
curl -fsS --max-time 8 "http://127.0.0.1:$PORT/" -o /tmp/mv924-before.html || fail 'Music Vault home page did not respond; no files changed.'

STEP='backups'
log 'Step 4/7: backing up app.py, template, new assets and installed-version marker'
mkdir -p "$BACKUP/static" "$BACKUP/templates" "$BACKUP/data"
cp -a "$APP_ROOT/app.py" "$BACKUP/app.py"
cp -a "$APP_ROOT/templates/index.html" "$BACKUP/templates/index.html"
if [[ -f "$APP_ROOT/static/mv924-home-repair.js" ]]; then
  HAD_JS=1
  cp -a "$APP_ROOT/static/mv924-home-repair.js" "$BACKUP/static/mv924-home-repair.js"
fi
if [[ -f "$APP_ROOT/static/mv924-home-repair.css" ]]; then
  HAD_CSS=1
  cp -a "$APP_ROOT/static/mv924-home-repair.css" "$BACKUP/static/mv924-home-repair.css"
fi
if [[ -f "$APP_ROOT/data/installed_version.txt" ]]; then
  HAD_VERSION=1
  cp -a "$APP_ROOT/data/installed_version.txt" "$BACKUP/data/installed_version.txt"
fi

STEP='Home feed and download-speed patch'
log 'Step 5/7: correcting mobile Recently Added layout, See All routing, benign Safari error banner and yt-dlp download options'
ROLLBACK_ACTIVE=1
python3 "$PKG_DIR/patch_home_downloads.py" "$APP_ROOT"
python3 -m py_compile "$APP_ROOT/app.py"
node --check "$APP_ROOT/static/mv924-home-repair.js"
chown "$OWNER:$GROUP" "$APP_ROOT/app.py" "$APP_ROOT/templates/index.html" "$APP_ROOT/static/mv924-home-repair.js" "$APP_ROOT/static/mv924-home-repair.css"

STEP='Flask template cache refresh'
log 'Step 6/7: restarting Music Vault once to refresh Flask/Jinja'
systemctl restart "$SERVICE"
wait_http || fail 'Music Vault did not return healthy within 30 seconds; rolling back.'

STEP='live HTML, asset and API verification'
log 'Step 7/7: verifying home assets, all primary tabs, Recently Added API and service health'
curl -fsS --max-time 8 "http://127.0.0.1:$PORT/" -o /tmp/mv924-live.html
curl -fsS --max-time 8 "http://127.0.0.1:$PORT/static/mv924-home-repair.js?v=9.24.0" -o /tmp/mv924-live.js
curl -fsS --max-time 8 "http://127.0.0.1:$PORT/static/mv924-home-repair.css?v=9.24.0" -o /tmp/mv924-live.css
curl -fsS --max-time 8 "http://127.0.0.1:$PORT/api/library/recent-albums?limit=2&offset=0" -o /tmp/mv924-recent.json
python3 - <<'PY'
import json
from pathlib import Path
p=json.loads(Path('/tmp/mv924-recent.json').read_text(encoding='utf-8'))
assert isinstance(p.get('items'), list), 'Recently Added API did not return items[]'
assert isinstance(p.get('total'), int), 'Recently Added API did not return total'
print(f"PASS: Recently Added API returned {len(p['items'])} items; total={p['total']}.")
PY
grep -q 'mv924-home-repair-css' /tmp/mv924-live.html || fail 'Live HTML is missing the home repair stylesheet.'
grep -q 'mv924-home-repair-js' /tmp/mv924-live.html || fail 'Live HTML is missing the home repair script.'
grep -q 'data-page="home"' /tmp/mv924-live.html || fail 'Listen Now tab is missing.'
grep -q 'data-page="new"' /tmp/mv924-live.html || fail 'New tab is missing.'
grep -q 'data-page="radio"' /tmp/mv924-live.html || fail 'Radio tab is missing.'
grep -q 'data-page="library"' /tmp/mv924-live.html || fail 'Library tab is missing.'
grep -q 'data-page="search"' /tmp/mv924-live.html || fail 'Search tab is missing.'
grep -q 'grid-template-columns: repeat(2, minmax(0, 1fr))' /tmp/mv924-live.css || fail 'Mobile Recently Added grid rule is missing.'
grep -q 'openRecentlyAddedAlbums' /tmp/mv924-live.js || fail 'Recently Added See All handler is missing.'
cmp -s "$APP_ROOT/static/mv924-home-repair.js" /tmp/mv924-live.js || fail 'Served home repair JavaScript differs from installed file.'
cmp -s "$APP_ROOT/static/mv924-home-repair.css" /tmp/mv924-live.css || fail 'Served home repair CSS differs from installed file.'
[[ "$(systemctl is-active "$SERVICE")" == active ]] || fail 'Music Vault service is not active after update.'
printf '9.24.0\n' > "$APP_ROOT/data/installed_version.txt"
chown "$OWNER:$GROUP" "$APP_ROOT/data/installed_version.txt"
ROLLBACK_ACTIVE=0
trap - ERR
log 'SUCCESS: 9.24.0 home layout, navigation shortcut, downloader settings, live API and service checks passed.'
log 'YouTube keeps best available source audio; HLS/DASH fragments can download 8 at a time and HTTP transfers use 10 MiB chunks where supported.'
log 'Music files, database, profiles, Favorites, history, playlists, queue, EQ, existing player bundle and service worker were not modified.'
log "Backup: $BACKUP"
