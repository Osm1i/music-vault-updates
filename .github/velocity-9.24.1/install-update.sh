#!/usr/bin/env bash
set -Eeuo pipefail
APP_ROOT="${MUSICVAULT_HOME:-/opt/music-vault}"
SERVICE="${MUSICVAULT_SERVICE:-music-vault.service}"
PORT="${MUSICVAULT_PORT:-8788}"
PKG_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$APP_ROOT/backups/vanguard-9.24.1-home-downloads-$STAMP"
OWNER="$(stat -c '%U' "$APP_ROOT" 2>/dev/null || echo root)"
GROUP="$(stat -c '%G' "$APP_ROOT" 2>/dev/null || echo root)"
ROLLBACK_ACTIVE=0
HAD_JS=0
HAD_CSS=0
HAD_VERSION=0
STEP='initializing'

log(){ printf '[Music Vault 9.24.1] %s\n' "$*"; }
fail(){ log "ERROR at $STEP: $*" >&2; return 1; }
wait_http(){
  local attempt
  for attempt in $(seq 1 30); do
    if systemctl is-active --quiet "$SERVICE" &&
       curl -fsS --max-time 3 "http://127.0.0.1:$PORT/" -o /tmp/mv9241-health.html; then
      return 0
    fi
    sleep 1
  done
  return 1
}
rollback(){
  local status="$1"
  local line="$2"
  trap - ERR
  if [[ "$ROLLBACK_ACTIVE" == 1 ]]; then
    set +e
    log "FAILURE: step=$STEP line=$line exit=$status. Restoring the backed-up app files."
    mkdir -p "$APP_ROOT/data/updates"
    printf 'step=%s\nline=%s\nexit=%s\nbackup=%s\ntime=%s\n' "$STEP" "$line" "$status" "$BACKUP" "$(date -Is)" > "$APP_ROOT/data/updates/last-install-failure-9.24.1.txt"
    [[ -f "$BACKUP/app.py" ]] && cp -a "$BACKUP/app.py" "$APP_ROOT/app.py"
    [[ -f "$BACKUP/templates/index.html" ]] && cp -a "$BACKUP/templates/index.html" "$APP_ROOT/templates/index.html"
    if [[ "$HAD_JS" == 1 && -f "$BACKUP/static/mv9241-home-repair.js" ]]; then
      cp -a "$BACKUP/static/mv9241-home-repair.js" "$APP_ROOT/static/mv9241-home-repair.js"
    else
      rm -f "$APP_ROOT/static/mv9241-home-repair.js"
    fi
    if [[ "$HAD_CSS" == 1 && -f "$BACKUP/static/mv9241-home-repair.css" ]]; then
      cp -a "$BACKUP/static/mv9241-home-repair.css" "$APP_ROOT/static/mv9241-home-repair.css"
    else
      rm -f "$APP_ROOT/static/mv9241-home-repair.css"
    fi
    if [[ "$HAD_VERSION" == 1 && -f "$BACKUP/data/installed_version.txt" ]]; then
      cp -a "$BACKUP/data/installed_version.txt" "$APP_ROOT/data/installed_version.txt"
    else
      rm -f "$APP_ROOT/data/installed_version.txt"
    fi
    chown "$OWNER:$GROUP" "$APP_ROOT/app.py" "$APP_ROOT/templates/index.html" 2>/dev/null || true
    [[ ! -f "$APP_ROOT/static/mv9241-home-repair.js" ]] || chown "$OWNER:$GROUP" "$APP_ROOT/static/mv9241-home-repair.js" 2>/dev/null || true
    [[ ! -f "$APP_ROOT/static/mv9241-home-repair.css" ]] || chown "$OWNER:$GROUP" "$APP_ROOT/static/mv9241-home-repair.css" 2>/dev/null || true
    log 'Restarting restored Music Vault to refresh Flask/Jinja.'
    systemctl restart "$SERVICE" || true
    wait_http || log 'WARNING: files were restored, but service health did not recover automatically.'
    log "Rollback completed. Music database, music files, profiles, playlists, favorites, history, playback bundle, service worker, queue and EQ were not modified. Backup: $BACKUP"
  else
    log "Installer stopped before live changes: step=$STEP line=$line exit=$status. No app files were changed."
  fi
  exit "$status"
}
trap 'rc=$?; line=$LINENO; rollback "$rc" "$line"' ERR

STEP='package and app layout validation'
log 'Step 1/7: validating package and Music Vault layout'
[[ "$(id -u)" == 0 ]] || fail 'Run installer as root.'
[[ -s "$APP_ROOT/app.py" && -s "$APP_ROOT/templates/index.html" && -d "$APP_ROOT/static" && -d "$APP_ROOT/data" ]] ||
  fail 'Music Vault app layout not found; no files changed.'
for file in install-update.sh patch_home_downloads.py mv9241-home-repair.js mv9241-home-repair.css tests/test_home_downloads.py SHA256SUMS_9_24_1.txt MUSIC_VAULT_RELEASE_VERSION.txt; do
  [[ -s "$PKG_DIR/$file" ]] || fail "Package file missing: $file"
done
(cd "$PKG_DIR" && sha256sum -c SHA256SUMS_9_24_1.txt)
[[ "$(tr -d '\r\n' < "$PKG_DIR/MUSIC_VAULT_RELEASE_VERSION.txt")" == 9.24.1 ]] || fail 'Package version marker mismatch.'

STEP='package regression tests'
log 'Step 2/7: running package regression tests'
python3 -m py_compile "$PKG_DIR/patch_home_downloads.py" "$PKG_DIR/tests/test_home_downloads.py"
python3 "$PKG_DIR/tests/test_home_downloads.py"
bash -n "$PKG_DIR/install-update.sh"
# No Node requirement here: Music Vault supports Deno as its primary yt-dlp
# runtime. JavaScript syntax is checked by the GitHub release build instead.

STEP='pre-update service health'
log 'Step 3/7: confirming service and home page before update'
systemctl is-active --quiet "$SERVICE" || fail 'Music Vault service is not active; no files changed.'
curl -fsS --max-time 8 "http://127.0.0.1:$PORT/" -o /tmp/mv9241-before.html || fail 'Music Vault home page did not respond; no files changed.'

STEP='backups'
log 'Step 4/7: backing up app.py, template, new assets and installed-version marker'
mkdir -p "$BACKUP/static" "$BACKUP/templates" "$BACKUP/data"
cp -a "$APP_ROOT/app.py" "$BACKUP/app.py"
cp -a "$APP_ROOT/templates/index.html" "$BACKUP/templates/index.html"
if [[ -f "$APP_ROOT/static/mv9241-home-repair.js" ]]; then
  HAD_JS=1
  cp -a "$APP_ROOT/static/mv9241-home-repair.js" "$BACKUP/static/mv9241-home-repair.js"
fi
if [[ -f "$APP_ROOT/static/mv9241-home-repair.css" ]]; then
  HAD_CSS=1
  cp -a "$APP_ROOT/static/mv9241-home-repair.css" "$BACKUP/static/mv9241-home-repair.css"
fi
if [[ -f "$APP_ROOT/data/installed_version.txt" ]]; then
  HAD_VERSION=1
  cp -a "$APP_ROOT/data/installed_version.txt" "$BACKUP/data/installed_version.txt"
fi

STEP='Home feed and download-speed patch'
log 'Step 5/7: restoring Home album rendering, Albums shortcut, Safari error recovery and yt-dlp download settings'
ROLLBACK_ACTIVE=1
python3 "$PKG_DIR/patch_home_downloads.py" "$APP_ROOT"
python3 -m py_compile "$APP_ROOT/app.py"
chown "$OWNER:$GROUP" "$APP_ROOT/app.py" "$APP_ROOT/templates/index.html" "$APP_ROOT/static/mv9241-home-repair.js" "$APP_ROOT/static/mv9241-home-repair.css"

STEP='Flask template cache refresh'
log 'Step 6/7: restarting Music Vault once to refresh Flask/Jinja'
systemctl restart "$SERVICE"
wait_http || fail 'Music Vault did not return healthy within 30 seconds; rolling back.'

STEP='live HTML, assets and Recently Added API verification'
log 'Step 7/7: verifying live Home assets, primary tabs, Recently Added API and service health'
curl -fsS --max-time 8 "http://127.0.0.1:$PORT/" -o /tmp/mv9241-live.html
curl -fsS --max-time 8 "http://127.0.0.1:$PORT/static/mv9241-home-repair.js?v=9.24.1" -o /tmp/mv9241-live.js
curl -fsS --max-time 8 "http://127.0.0.1:$PORT/static/mv9241-home-repair.css?v=9.24.1" -o /tmp/mv9241-live.css
curl -fsS --max-time 8 "http://127.0.0.1:$PORT/api/library/recent-albums?limit=2&offset=0" -o /tmp/mv9241-recent.json
python3 - <<'PY'
import json
from pathlib import Path
payload=json.loads(Path('/tmp/mv9241-recent.json').read_text(encoding='utf-8'))
assert isinstance(payload.get('items'), list), 'Recently Added API did not return items[]'
assert isinstance(payload.get('total'), int), 'Recently Added API did not return total'
print(f"PASS: Recently Added API returned {len(payload['items'])} rows; total={payload['total']}.")
PY
grep -q 'mv9241-home-repair-css' /tmp/mv9241-live.html || fail 'Live HTML is missing the Home repair stylesheet.'
grep -q 'mv9241-home-repair-js' /tmp/mv9241-live.html || fail 'Live HTML is missing the Home repair script.'
for tab in home new radio library search; do
  grep -q "data-page=\"$tab\"" /tmp/mv9241-live.html || fail "Live HTML is missing the $tab navigation tab."
done
grep -q 'grid-template-columns: repeat(2, minmax(0, 1fr))' /tmp/mv9241-live.css || fail 'Mobile Recently Added grid rule is missing.'
grep -q 'scheduleHomeRepair' /tmp/mv9241-live.js || fail 'Home recovery script is missing its refresh handler.'
cmp -s "$APP_ROOT/static/mv9241-home-repair.js" /tmp/mv9241-live.js || fail 'Served Home repair JavaScript differs from installed file.'
cmp -s "$APP_ROOT/static/mv9241-home-repair.css" /tmp/mv9241-live.css || fail 'Served Home repair CSS differs from installed file.'
[[ "$(systemctl is-active "$SERVICE")" == active ]] || fail 'Music Vault service is not active after update.'
printf '9.24.1\n' > "$APP_ROOT/data/installed_version.txt"
chown "$OWNER:$GROUP" "$APP_ROOT/data/installed_version.txt"
ROLLBACK_ACTIVE=0
trap - ERR
log 'SUCCESS: 9.24.1 Home layout, navigation, downloader settings, live API and service checks passed.'
log 'No Node executable was required on CasaOS; Deno remains the supported YouTube JS runtime.'
log 'Music, database, profiles, playlists, favorites, history, existing playback bundle, service worker, queue and EQ were not modified.'
log "Backup: $BACKUP"
