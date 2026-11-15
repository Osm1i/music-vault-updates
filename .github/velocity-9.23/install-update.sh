#!/usr/bin/env bash
set -Eeuo pipefail
APP_ROOT="${MUSICVAULT_HOME:-/opt/music-vault}"
SERVICE="${MUSICVAULT_SERVICE:-music-vault.service}"
PORT="${MUSICVAULT_PORT:-8788}"
PKG_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$APP_ROOT/backups/vanguard-9.23.0-player-controls-$STAMP"
OWNER="$(stat -c '%U' "$APP_ROOT" 2>/dev/null || echo root)"
GROUP="$(stat -c '%G' "$APP_ROOT" 2>/dev/null || echo root)"
ROLLBACK_ACTIVE=0
HAD_JS=0
HAD_CSS=0
HAD_VERSION=0
STEP='initializing'

log(){ printf '[Music Vault 9.23.0] %s\n' "$*"; }
wait_http(){
  local attempt
  for attempt in $(seq 1 30); do
    if systemctl is-active --quiet "$SERVICE" &&
       curl -fsS --max-time 3 "http://127.0.0.1:$PORT/" -o /tmp/mv923-health.html; then
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
    log "Failure at $STEP; restoring backed-up app files."
    [[ -f "$BACKUP/templates/index.html" ]] &&
      cp -a "$BACKUP/templates/index.html" "$APP_ROOT/templates/index.html"
    if [[ "$HAD_JS" == 1 && -f "$BACKUP/static/mv923-player-controls.js" ]]; then
      cp -a "$BACKUP/static/mv923-player-controls.js" "$APP_ROOT/static/mv923-player-controls.js"
    else
      rm -f "$APP_ROOT/static/mv923-player-controls.js"
    fi
    if [[ "$HAD_CSS" == 1 && -f "$BACKUP/static/mv923-player-controls.css" ]]; then
      cp -a "$BACKUP/static/mv923-player-controls.css" "$APP_ROOT/static/mv923-player-controls.css"
    else
      rm -f "$APP_ROOT/static/mv923-player-controls.css"
    fi
    if [[ "$HAD_VERSION" == 1 && -f "$BACKUP/data/installed_version.txt" ]]; then
      cp -a "$BACKUP/data/installed_version.txt" "$APP_ROOT/data/installed_version.txt"
    else
      rm -f "$APP_ROOT/data/installed_version.txt"
    fi
    chown "$OWNER:$GROUP" "$APP_ROOT/templates/index.html" 2>/dev/null || true
    [[ ! -f "$APP_ROOT/static/mv923-player-controls.js" ]] ||
      chown "$OWNER:$GROUP" "$APP_ROOT/static/mv923-player-controls.js" 2>/dev/null || true
    [[ ! -f "$APP_ROOT/static/mv923-player-controls.css" ]] ||
      chown "$OWNER:$GROUP" "$APP_ROOT/static/mv923-player-controls.css" 2>/dev/null || true
    log 'Restarting restored app to clear Flask/Jinja template cache.'
    systemctl restart "$SERVICE" || true
    wait_http || log 'WARNING: source files were restored, but service health did not recover automatically.'
    log "Rollback finished. app.py, the playback bundle, service worker, database, profiles, playlists, queue records, EQ settings and music files were not modified. Backup: $BACKUP"
  fi
  exit "$status"
}
trap rollback ERR

STEP='package and app layout validation'
log 'Step 1/7: validating package and Music Vault layout'
[[ "$(id -u)" == 0 ]]
[[ -s "$APP_ROOT/app.py" && -s "$APP_ROOT/templates/index.html" && -d "$APP_ROOT/static" && -d "$APP_ROOT/data" ]]
for file in install-update.sh patch_player_controls.py mv923-player-controls.js mv923-player-controls.css tests/test_player_controls.py SHA256SUMS_9_23_0.txt MUSIC_VAULT_RELEASE_VERSION.txt; do
  [[ -s "$PKG_DIR/$file" ]]
done
(cd "$PKG_DIR" && sha256sum -c SHA256SUMS_9_23_0.txt)
[[ "$(tr -d '\r\n' < "$PKG_DIR/MUSIC_VAULT_RELEASE_VERSION.txt")" == 9.23.0 ]]

STEP='package regression tests'
log 'Step 2/7: running package regression tests'
python3 -m py_compile "$PKG_DIR/patch_player_controls.py" "$PKG_DIR/tests/test_player_controls.py"
python3 "$PKG_DIR/tests/test_player_controls.py"
bash -n "$PKG_DIR/install-update.sh"

STEP='pre-update service health'
log 'Step 3/7: confirming service and home page before update'
systemctl is-active --quiet "$SERVICE"
curl -fsS --max-time 8 "http://127.0.0.1:$PORT/" -o /tmp/mv923-before.html

STEP='backups'
log 'Step 4/7: backing up template, player controls assets and version marker'
mkdir -p "$BACKUP/templates" "$BACKUP/static" "$BACKUP/data"
cp -a "$APP_ROOT/templates/index.html" "$BACKUP/templates/index.html"
if [[ -f "$APP_ROOT/static/mv923-player-controls.js" ]]; then
  HAD_JS=1
  cp -a "$APP_ROOT/static/mv923-player-controls.js" "$BACKUP/static/mv923-player-controls.js"
fi
if [[ -f "$APP_ROOT/static/mv923-player-controls.css" ]]; then
  HAD_CSS=1
  cp -a "$APP_ROOT/static/mv923-player-controls.css" "$BACKUP/static/mv923-player-controls.css"
fi
if [[ -f "$APP_ROOT/data/installed_version.txt" ]]; then
  HAD_VERSION=1
  cp -a "$APP_ROOT/data/installed_version.txt" "$BACKUP/data/installed_version.txt"
fi

STEP='favorite and clear-player controls patch'
log 'Step 5/7: adding red/outline profile favorites and the stop-and-clear X action'
ROLLBACK_ACTIVE=1
python3 "$PKG_DIR/patch_player_controls.py" "$APP_ROOT"
chown "$OWNER:$GROUP" "$APP_ROOT/templates/index.html" "$APP_ROOT/static/mv923-player-controls.js" "$APP_ROOT/static/mv923-player-controls.css"

STEP='Flask template cache refresh'
log 'Step 6/7: restarting Music Vault once to refresh Flask/Jinja'
systemctl restart "$SERVICE"
wait_http

STEP='live player controls verification'
log 'Step 7/7: verifying live player markup, JavaScript, CSS and service health'
curl -fsS --max-time 8 "http://127.0.0.1:$PORT/" -o /tmp/mv923-live.html
curl -fsS --max-time 8 "http://127.0.0.1:$PORT/static/mv923-player-controls.js?v=9.23.0" -o /tmp/mv923-live.js
curl -fsS --max-time 8 "http://127.0.0.1:$PORT/static/mv923-player-controls.css?v=9.23.0" -o /tmp/mv923-live.css
grep -q 'id="miniClear"' /tmp/mv923-live.html
grep -q 'window.mv923ClearPlayer' /tmp/mv923-live.html
grep -q 'mv923-player-controls-css' /tmp/mv923-live.html
grep -q 'mv923-player-controls-js' /tmp/mv923-live.html
grep -q 'mv923SetFavoriteState' /tmp/mv923-live.js
grep -q '#miniLike.is-favorite' /tmp/mv923-live.css
cmp -s "$APP_ROOT/static/mv923-player-controls.js" /tmp/mv923-live.js
cmp -s "$APP_ROOT/static/mv923-player-controls.css" /tmp/mv923-live.css
[[ "$(systemctl is-active "$SERVICE")" == active ]]
printf '9.23.0\n' > "$APP_ROOT/data/installed_version.txt"
chown "$OWNER:$GROUP" "$APP_ROOT/data/installed_version.txt"
ROLLBACK_ACTIVE=0
trap - ERR
log 'SUCCESS: 9.23.0 favorite state and stop/clear controls passed live HTML/asset and service checks.'
log 'The X stops audio, clears the complete playback queue and saved player state, then hides the mini-player. Music files and library records are untouched.'
log 'app.py, the playback bundle, service worker, database, profiles, playlists, EQ and USB settings were not modified.'
log "Backup: $BACKUP"
