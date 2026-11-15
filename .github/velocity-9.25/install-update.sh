#!/usr/bin/env bash
set -Eeuo pipefail
APP_ROOT="${MUSICVAULT_HOME:-/opt/music-vault}"
SERVICE="${MUSICVAULT_SERVICE:-music-vault.service}"
PORT="${MUSICVAULT_PORT:-8788}"
PKG_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$APP_ROOT/backups/vanguard-9.25.0-recent-added-rail-$STAMP"
OWNER="$(stat -c '%U' "$APP_ROOT" 2>/dev/null || echo root)"
GROUP="$(stat -c '%G' "$APP_ROOT" 2>/dev/null || echo root)"
ROLLBACK_ACTIVE=0
HAD_CSS=0
HAD_VERSION=0
STEP='initializing'

log(){ printf '[Music Vault 9.25.0] %s\n' "$*"; }
fail(){ log "ERROR at $STEP: $*" >&2; return 1; }
wait_http(){
  local attempt
  for attempt in $(seq 1 30); do
    if systemctl is-active --quiet "$SERVICE" &&
       curl -fsS --max-time 3 "http://127.0.0.1:$PORT/" -o /tmp/mv925-health.html; then
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
    log "FAILURE: step=$STEP line=$line exit=$status. Restoring the previous Home template and assets."
    mkdir -p "$APP_ROOT/data/updates"
    printf 'step=%s\nline=%s\nexit=%s\nbackup=%s\ntime=%s\n' "$STEP" "$line" "$status" "$BACKUP" "$(date -Is)" > "$APP_ROOT/data/updates/last-install-failure-9.25.0.txt"
    [[ -f "$BACKUP/templates/index.html" ]] && cp -a "$BACKUP/templates/index.html" "$APP_ROOT/templates/index.html"
    if [[ "$HAD_CSS" == 1 && -f "$BACKUP/static/mv925-recent-picks.css" ]]; then
      cp -a "$BACKUP/static/mv925-recent-picks.css" "$APP_ROOT/static/mv925-recent-picks.css"
    else
      rm -f "$APP_ROOT/static/mv925-recent-picks.css"
    fi
    if [[ "$HAD_VERSION" == 1 && -f "$BACKUP/data/installed_version.txt" ]]; then
      cp -a "$BACKUP/data/installed_version.txt" "$APP_ROOT/data/installed_version.txt"
    else
      rm -f "$APP_ROOT/data/installed_version.txt"
    fi
    chown "$OWNER:$GROUP" "$APP_ROOT/templates/index.html" 2>/dev/null || true
    [[ ! -f "$APP_ROOT/static/mv925-recent-picks.css" ]] || chown "$OWNER:$GROUP" "$APP_ROOT/static/mv925-recent-picks.css" 2>/dev/null || true
    log 'Restarting the restored app to refresh Flask/Jinja.'
    systemctl restart "$SERVICE" || true
    wait_http || log 'WARNING: previous files were restored, but the health check did not recover automatically.'
    log "Rollback completed. Music, database, profiles, playlists, Favorites, history, playback, service worker, queue, EQ and downloader settings were not modified. Backup: $BACKUP"
  else
    log "Installer stopped before live changes: step=$STEP line=$line exit=$status. No app files were changed."
  fi
  exit "$status"
}
trap 'rc=$?; line=$LINENO; rollback "$rc" "$line"' ERR

STEP='package and app layout validation'
log 'Step 1/6: validating package and Music Vault installation'
[[ "$(id -u)" == 0 ]] || fail 'Run installer as root.'
[[ -s "$APP_ROOT/templates/index.html" && -d "$APP_ROOT/static" && -d "$APP_ROOT/data" ]] || fail 'Music Vault app layout not found; no files changed.'
for file in install-update.sh patch_recent_added.py mv925-recent-picks.css tests/test_recent_added.py SHA256SUMS_9_25_0.txt MUSIC_VAULT_RELEASE_VERSION.txt; do
  [[ -s "$PKG_DIR/$file" ]] || fail "Package file missing: $file"
done
(cd "$PKG_DIR" && sha256sum -c SHA256SUMS_9_25_0.txt)
[[ "$(tr -d '\r\n' < "$PKG_DIR/MUSIC_VAULT_RELEASE_VERSION.txt")" == 9.25.0 ]] || fail 'Package version marker mismatch.'

STEP='package regression tests'
log 'Step 2/6: running package regression tests'
python3 -m py_compile "$PKG_DIR/patch_recent_added.py" "$PKG_DIR/tests/test_recent_added.py"
python3 "$PKG_DIR/tests/test_recent_added.py"
bash -n "$PKG_DIR/install-update.sh"

STEP='pre-update service health'
log 'Step 3/6: checking the running app before changes'
systemctl is-active --quiet "$SERVICE" || fail 'Music Vault service is not active; no files changed.'
curl -fsS --max-time 8 "http://127.0.0.1:$PORT/" -o /tmp/mv925-before.html || fail 'Music Vault Home page did not respond; no files changed.'
grep -q 'id="recentAlbums"' /tmp/mv925-before.html || fail 'Live Home page does not contain the Recently Added album container; no files changed.'

STEP='backups'
log 'Step 4/6: backing up Home template, new stylesheet and version marker'
mkdir -p "$BACKUP/templates" "$BACKUP/static" "$BACKUP/data"
cp -a "$APP_ROOT/templates/index.html" "$BACKUP/templates/index.html"
if [[ -f "$APP_ROOT/static/mv925-recent-picks.css" ]]; then
  HAD_CSS=1
  cp -a "$APP_ROOT/static/mv925-recent-picks.css" "$BACKUP/static/mv925-recent-picks.css"
fi
if [[ -f "$APP_ROOT/data/installed_version.txt" ]]; then
  HAD_VERSION=1
  cp -a "$APP_ROOT/data/installed_version.txt" "$BACKUP/data/installed_version.txt"
fi

STEP='Recently Added Top Picks-style layout patch'
log 'Step 5/6: switching Recently Added to compact horizontal album cards'
ROLLBACK_ACTIVE=1
python3 "$PKG_DIR/patch_recent_added.py" "$APP_ROOT"
chown "$OWNER:$GROUP" "$APP_ROOT/templates/index.html" "$APP_ROOT/static/mv925-recent-picks.css"

STEP='Flask template refresh and live validation'
log 'Step 6/6: restarting once and verifying the actual Home page and stylesheet'
systemctl restart "$SERVICE"
wait_http || fail 'Music Vault did not return healthy within 30 seconds; rolling back.'
curl -fsS --max-time 8 "http://127.0.0.1:$PORT/" -o /tmp/mv925-live.html
curl -fsS --max-time 8 "http://127.0.0.1:$PORT/static/mv925-recent-picks.css?v=9.25.0" -o /tmp/mv925-live.css
grep -q 'mv925-recent-picks-css' /tmp/mv925-live.html || fail 'Live Home HTML is missing the new Recently Added stylesheet.'
grep -q 'display: flex !important' /tmp/mv925-live.css || fail 'Live CSS did not enable the horizontal carousel.'
grep -q 'overflow-x: auto !important' /tmp/mv925-live.css || fail 'Live CSS did not enable horizontal scrolling.'
grep -q 'flex: 0 0 clamp(112px, 29vw, 132px) !important' /tmp/mv925-live.css || fail 'Live CSS is missing compact card sizing.'
for tab in home new radio library search; do
  grep -q "data-page=\"$tab\"" /tmp/mv925-live.html || fail "Live navigation is missing the $tab tab."
done
cmp -s "$APP_ROOT/static/mv925-recent-picks.css" /tmp/mv925-live.css || fail 'Served stylesheet differs from installed file.'
[[ "$(systemctl is-active "$SERVICE")" == active ]] || fail 'Music Vault service is not active after update.'
printf '9.25.0\n' > "$APP_ROOT/data/installed_version.txt"
chown "$OWNER:$GROUP" "$APP_ROOT/data/installed_version.txt"
ROLLBACK_ACTIVE=0
trap - ERR
log 'SUCCESS: Recently Added now uses the compact Top Picks-style horizontal album-card rail.'
log 'Album data, newest-first ordering, card click handlers, collection count, heading and View All action are preserved.'
log 'No music files, database, app backend, playback bundle, service worker, profiles, playlists or downloader configuration were modified.'
log "Backup: $BACKUP"
