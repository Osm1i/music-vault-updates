#!/usr/bin/env bash
set -Eeuo pipefail
APP_ROOT="${MUSICVAULT_HOME:-/opt/music-vault}"
SERVICE="${MUSICVAULT_SERVICE:-music-vault.service}"
PORT="${MUSICVAULT_PORT:-8788}"
PKG_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$APP_ROOT/backups/vanguard-9.26.1-ambient-cards-download-speed-$STAMP"
OWNER="$(stat -c '%U' "$APP_ROOT" 2>/dev/null || echo root)"
GROUP="$(stat -c '%G' "$APP_ROOT" 2>/dev/null || echo root)"
ROLLBACK_ACTIVE=0
HAD_CSS=0
HAD_VERSION=0
STEP='initializing'

log(){ printf '[Music Vault 9.26.1] %s\n' "$*"; }
fail(){ log "ERROR at $STEP: $*" >&2; return 1; }
wait_http(){
  local attempt
  for attempt in $(seq 1 30); do
    if systemctl is-active --quiet "$SERVICE" &&
       curl -fsS --max-time 3 "http://127.0.0.1:$PORT/" -o /tmp/mv926-health.html; then
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
  mkdir -p "$APP_ROOT/data/updates"
  printf 'step=%s\nline=%s\nexit=%s\nbackup=%s\ntime=%s\n' "$STEP" "$line" "$status" "$BACKUP" "$(date -Is)" > "$APP_ROOT/data/updates/last-install-failure-9.26.1.txt"
  if [[ "$ROLLBACK_ACTIVE" == 1 ]]; then
    set +e
    log "FAILURE: step=$STEP line=$line exit=$status. Restoring the backed-up app files."
    [[ ! -f "$BACKUP/app.py" ]] || cp -a "$BACKUP/app.py" "$APP_ROOT/app.py"
    [[ ! -f "$BACKUP/templates/index.html" ]] || cp -a "$BACKUP/templates/index.html" "$APP_ROOT/templates/index.html"
    if [[ "$HAD_CSS" == 1 && -f "$BACKUP/static/mv926-ambient-cards.css" ]]; then
      cp -a "$BACKUP/static/mv926-ambient-cards.css" "$APP_ROOT/static/mv926-ambient-cards.css"
    else
      rm -f "$APP_ROOT/static/mv926-ambient-cards.css"
    fi
    if [[ "$HAD_VERSION" == 1 && -f "$BACKUP/data/installed_version.txt" ]]; then
      cp -a "$BACKUP/data/installed_version.txt" "$APP_ROOT/data/installed_version.txt"
    else
      rm -f "$APP_ROOT/data/installed_version.txt"
    fi
    chown "$OWNER:$GROUP" "$APP_ROOT/app.py" "$APP_ROOT/templates/index.html" 2>/dev/null || true
    [[ ! -f "$APP_ROOT/static/mv926-ambient-cards.css" ]] || chown "$OWNER:$GROUP" "$APP_ROOT/static/mv926-ambient-cards.css" 2>/dev/null || true
    log 'Restarting the restored app to refresh Flask/Jinja.'
    systemctl restart "$SERVICE" || true
    wait_http || log 'WARNING: previous files were restored, but the health check did not recover automatically.'
    log "Rollback completed. Music, database, profiles, playlists, favorites, history, playback bundle, service worker and prior Home layout were preserved. Backup: $BACKUP"
  else
    log "Installer stopped before live changes: step=$STEP line=$line exit=$status. No app files were changed."
  fi
  exit "$status"
}
trap 'rc=$?; line=$LINENO; rollback "$rc" "$line"' ERR

STEP='package and app layout validation'
log 'Step 1/6: validating the package and Music Vault installation'
[[ "$(id -u)" == 0 ]] || fail 'Run installer as root.'
[[ -s "$APP_ROOT/app.py" && -s "$APP_ROOT/templates/index.html" && -d "$APP_ROOT/static" && -d "$APP_ROOT/data" ]] || fail 'Music Vault app layout not found; no files changed.'
[[ -s "$APP_ROOT/static/mv-consolidated.js" && -s "$APP_ROOT/static/sw.js" ]] || fail 'Existing Home renderer or service worker is missing; no files changed.'
for file in install-update.sh patch_ambient_cards.py mv926-ambient-cards.css tests/test_ambient_cards.py SHA256SUMS_9_26_0.txt MUSIC_VAULT_RELEASE_VERSION.txt; do
  [[ -s "$PKG_DIR/$file" ]] || fail "Package file missing: $file"
done
(cd "$PKG_DIR" && sha256sum -c SHA256SUMS_9_26_0.txt)
[[ "$(tr -d '\r\n' < "$PKG_DIR/MUSIC_VAULT_RELEASE_VERSION.txt")" == 9.26.1 ]] || fail 'Package version marker mismatch.'
grep -q 'mv81-mood-card' "$APP_ROOT/static/mv-consolidated.js" || fail 'Current Home renderer does not contain the expected mood-card component.'
grep -q 'mv81-station-card' "$APP_ROOT/static/mv-consolidated.js" || fail 'Current Home renderer does not contain the expected station-card component.'

STEP='package regression tests'
log 'Step 2/6: running package regression tests'
python3 -m py_compile "$PKG_DIR/patch_ambient_cards.py" "$PKG_DIR/tests/test_ambient_cards.py"
python3 "$PKG_DIR/tests/test_ambient_cards.py"
bash -n "$PKG_DIR/install-update.sh"

STEP='pre-update service health'
log 'Step 3/6: checking the running app before changes'
systemctl is-active --quiet "$SERVICE" || fail 'Music Vault service is not active; no files changed.'
curl -fsS --max-time 8 "http://127.0.0.1:$PORT/" -o /tmp/mv926-before.html || fail 'Music Vault Home page did not respond; no files changed.'
grep -q 'id="page-home"' /tmp/mv926-before.html || fail 'Live Home page markup was not found; no files changed.'
BASE_PLAYER_HASH="$(sha256sum "$APP_ROOT/static/mv-consolidated.js" | awk '{print $1}')"
BASE_SW_HASH="$(sha256sum "$APP_ROOT/static/sw.js" | awk '{print $1}')"

STEP='backups'
log 'Step 4/6: backing up app.py, Home template, new stylesheet and version marker'
mkdir -p "$BACKUP/static" "$BACKUP/templates" "$BACKUP/data"
cp -a "$APP_ROOT/app.py" "$BACKUP/app.py"
cp -a "$APP_ROOT/templates/index.html" "$BACKUP/templates/index.html"
if [[ -f "$APP_ROOT/static/mv926-ambient-cards.css" ]]; then
  HAD_CSS=1
  cp -a "$APP_ROOT/static/mv926-ambient-cards.css" "$BACKUP/static/mv926-ambient-cards.css"
fi
if [[ -f "$APP_ROOT/data/installed_version.txt" ]]; then
  HAD_VERSION=1
  cp -a "$APP_ROOT/data/installed_version.txt" "$BACKUP/data/installed_version.txt"
fi

STEP='ambient card animations and YouTube throughput tuning'
log 'Step 5/6: adding GPU-friendly mood/station animations and tuning YouTube fragment concurrency to 12 while retaining best-audio selection'
ROLLBACK_ACTIVE=1
python3 "$PKG_DIR/patch_ambient_cards.py" "$APP_ROOT"
python3 - "$APP_ROOT/app.py" <<'PY'
import ast
from pathlib import Path
import sys
source=Path(sys.argv[1]).read_text(encoding='utf-8')
ast.parse(source)
assert "'format':'bestaudio/best'" in source
assert "'concurrent_fragment_downloads':12" in source
assert "'http_chunk_size':10*1024*1024" in source
assert "'buffersize':1024*1024" in source
assert "'-c:a','copy'" in source, 'Original Opus stream must remain a stream-copy remux, not a re-encode.'
PY
chown "$OWNER:$GROUP" "$APP_ROOT/app.py" "$APP_ROOT/templates/index.html" "$APP_ROOT/static/mv926-ambient-cards.css"

STEP='Flask template refresh'
log 'Step 6/6: restarting once and checking live HTML, CSS, downloader settings and untouched playback assets'
systemctl restart "$SERVICE"
wait_http || fail 'Music Vault did not return healthy within 30 seconds; rolling back.'
curl -fsS --max-time 8 "http://127.0.0.1:$PORT/" -o /tmp/mv926-live.html
curl -fsS --max-time 8 "http://127.0.0.1:$PORT/static/mv926-ambient-cards.css?v=9.26.1" -o /tmp/mv926-live.css
grep -q 'mv926-ambient-cards-css' /tmp/mv926-live.html || fail 'Live Home HTML is missing the ambient animation stylesheet.'
grep -q 'mv81-mood-card' /tmp/mv926-live.css || fail 'Mood-card animation rules are missing.'
grep -q 'mv81-station-card' /tmp/mv926-live.css || fail 'Station-card animation rules are missing.'
grep -q 'prefers-reduced-motion: reduce' /tmp/mv926-live.css || fail 'Reduced-motion accessibility rules are missing.'
cmp -s "$APP_ROOT/static/mv926-ambient-cards.css" /tmp/mv926-live.css || fail 'Served animation stylesheet differs from installed file.'
[[ "$(sha256sum "$APP_ROOT/static/mv-consolidated.js" | awk '{print $1}')" == "$BASE_PLAYER_HASH" ]] || fail 'Existing playback/Home renderer JavaScript changed unexpectedly.'
[[ "$(sha256sum "$APP_ROOT/static/sw.js" | awk '{print $1}')" == "$BASE_SW_HASH" ]] || fail 'Existing service worker changed unexpectedly.'
python3 - "$APP_ROOT/app.py" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text(encoding='utf-8')
assert "'format':'bestaudio/best'" in s
assert "'concurrent_fragment_downloads':12" in s
assert "'http_chunk_size':10*1024*1024" in s
assert "'buffersize':1024*1024" in s
assert "'-c:a','copy'" in s
print('PASS: best available audio selector, 12 fragment workers, 10 MiB HTTP chunks, 1 MiB buffer and copy-only Opus remux verified.')
PY
[[ "$(systemctl is-active "$SERVICE")" == active ]] || fail 'Music Vault service is not active after update.'
printf '9.26.1\n' > "$APP_ROOT/data/installed_version.txt"
chown "$OWNER:$GROUP" "$APP_ROOT/data/installed_version.txt"
ROLLBACK_ACTIVE=0
trap - ERR
log 'SUCCESS: Home mood/station cards now have ambient animation; YouTube downloads are tuned for 12 concurrent HLS/DASH fragments.'
log 'Best-audio source selection is unchanged; Opus remux remains stream-copy only, with no audio re-encoding.'
log 'Existing Recently Added layout, Home renderer, playback JavaScript, service worker, music database, files, profiles and playlists were preserved.'
log "Backup: $BACKUP"
