#!/usr/bin/env bash
set -Eeuo pipefail
APP_ROOT="${DEALHUNTER_APP_ROOT:-/home/osmii/dealhunter-server}"
BACKUP_ROOT="${DEALHUNTER_BACKUP_ROOT:-/home/osmii/dealhunter-backups}"
PKG_ROOT="$(cd "$(dirname "$0")" && pwd)"
VERSION="$(tr -d '\r\n' < "$PKG_ROOT/DEALHUNTER_VERSION.txt")"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Invalid DealHunter version: $VERSION" >&2; exit 2; }
test -d "$APP_ROOT" || { echo "DealHunter app root not found: $APP_ROOT" >&2; exit 2; }
for f in mobile.html manifest.webmanifest dealhunter-sw.js dealhunter-icon-192.png dealhunter-icon-512.png check-dealhunter-update.sh install-update.sh; do
  test -s "$PKG_ROOT/$f" || { echo "Release package missing required file: $f" >&2; exit 2; }
done
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$BACKUP_ROOT/mobile-$STAMP"
mkdir -p "$BACKUP" /usr/local/sbin
FILES=(mobile.html manifest.webmanifest dealhunter-sw.js dealhunter-icon-192.png dealhunter-icon-512.png DEALHUNTER_VERSION.txt dealhunter-update-status.json)
for f in "${FILES[@]}"; do
  if [[ -f "$APP_ROOT/$f" ]]; then cp -a "$APP_ROOT/$f" "$BACKUP/$f"; fi
done
if [[ -f /usr/local/sbin/dealhunter-update-check.sh ]]; then cp -a /usr/local/sbin/dealhunter-update-check.sh "$BACKUP/dealhunter-update-check.sh"; fi
ROLLBACK_READY=1
rollback(){
  [[ "$ROLLBACK_READY" == 1 ]] || return 0
  echo "Install health check failed. Restoring the previous DealHunter mobile release." >&2
  for f in "${FILES[@]}"; do
    if [[ -f "$BACKUP/$f" ]]; then cp -a "$BACKUP/$f" "$APP_ROOT/$f"; else rm -f "$APP_ROOT/$f"; fi
  done
  if [[ -f "$BACKUP/dealhunter-update-check.sh" ]]; then cp -a "$BACKUP/dealhunter-update-check.sh" /usr/local/sbin/dealhunter-update-check.sh; fi
}
on_exit(){ rc=$?; if [[ $rc -ne 0 ]]; then rollback; fi; exit "$rc"; }
trap on_exit EXIT
for f in mobile.html manifest.webmanifest dealhunter-sw.js dealhunter-icon-192.png dealhunter-icon-512.png; do
  install -m 0644 "$PKG_ROOT/$f" "$APP_ROOT/.$f.new"
  mv -f "$APP_ROOT/.$f.new" "$APP_ROOT/$f"
done
install -m 0644 "$PKG_ROOT/DEALHUNTER_VERSION.txt" "$APP_ROOT/.DEALHUNTER_VERSION.txt.new"
mv -f "$APP_ROOT/.DEALHUNTER_VERSION.txt.new" "$APP_ROOT/DEALHUNTER_VERSION.txt"
install -m 0644 "$PKG_ROOT/dealhunter-update-status.json" "$APP_ROOT/.dealhunter-update-status.json.new"
mv -f "$APP_ROOT/.dealhunter-update-status.json.new" "$APP_ROOT/dealhunter-update-status.json"
install -m 0755 "$PKG_ROOT/check-dealhunter-update.sh" /usr/local/sbin/dealhunter-update-check.sh
install -m 0755 "$PKG_ROOT/install-update.sh" /usr/local/sbin/dealhunter-install-update.sh
if ! curl -fsS --max-time 15 http://127.0.0.1:8787/ > "$BACKUP/healthcheck.html"; then
  echo "DealHunter service did not respond on 127.0.0.1:8787." >&2
  exit 10
fi
if ! grep -q "GHOST-PROTOCOL-$VERSION" "$BACKUP/healthcheck.html"; then
  echo "The server is responding, but it is not serving the new mobile release marker." >&2
  exit 11
fi
python3 - "$APP_ROOT/dealhunter-update-status.json" "$VERSION" <<'PY'
import json,sys,datetime
path,version=sys.argv[1:]
now=datetime.datetime.now(datetime.timezone.utc)
next_check=now+datetime.timedelta(minutes=15)
with open(path,'w') as f:
 json.dump({'version':version,'latestVersion':version,'status':'installed','message':f'DealHunter {version} is installed. GitHub checks run every 15 minutes.','lastCheck':now.isoformat(),'nextCheck':next_check.isoformat(),'channel':'github-releases'},f,indent=2)
 f.write('\n')
PY
ROLLBACK_READY=0
trap - EXIT
echo "DealHunter mobile UI $VERSION installed and health-checked."
echo "Backup retained at: $BACKUP"
