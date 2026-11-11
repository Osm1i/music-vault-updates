#!/usr/bin/env bash
set -Eeuo pipefail
REPO="${DEALHUNTER_GITHUB_REPO:-Osm1i/music-vault-updates}"
APP_ROOT="${DEALHUNTER_APP_ROOT:-/home/osmii/dealhunter-server}"
OSMII_HOME="/home/osmii"
GH_CONFIG_DIR="$OSMII_HOME/.config/gh"
LOG="/var/log/dealhunter-update.log"
STATUS="$APP_ROOT/dealhunter-update-status.json"
mkdir -p "$(dirname "$LOG")" "$APP_ROOT"
exec >>"$LOG" 2>&1
echo "[$(date -Is)] DealHunter release check started."
write_status(){
  local current="$1" latest="$2" state="$3" message="$4"
  python3 - "$STATUS" "$current" "$latest" "$state" "$message" <<'PY'
import json,sys,datetime
path,current,latest,status,message=sys.argv[1:]
now=datetime.datetime.now(datetime.timezone.utc)
next_check=now+datetime.timedelta(minutes=15)
with open(path,'w') as f:
 json.dump({'version':current or 'unknown','latestVersion':latest or current or 'unknown','status':status,'message':message[:500],'lastCheck':now.isoformat(),'nextCheck':next_check.isoformat(),'channel':'github-releases'},f,indent=2)
 f.write('\n')
PY
}
CURRENT="$(tr -d '\r\n' < "$APP_ROOT/DEALHUNTER_VERSION.txt" 2>/dev/null || echo 0.0.0)"
GH="$(command -v gh || true)"
if [[ -z "$GH" ]]; then write_status "$CURRENT" "" "error" "GitHub CLI is missing on the server."; echo "GitHub CLI missing."; exit 2; fi
as_osmii(){ runuser -u osmii -- env HOME="$OSMII_HOME" GH_CONFIG_DIR="$GH_CONFIG_DIR" "$GH" "$@"; }
if ! as_osmii auth status --hostname github.com >/dev/null 2>&1; then
  write_status "$CURRENT" "" "auth-required" "GitHub release access needs one-time server sign-in."; echo "GitHub CLI is not authenticated for osmii."; exit 3
fi
if ! TAGS="$(as_osmii release list --repo "$REPO" --limit 100 --json tagName,isDraft,isPrerelease --jq '.[] | select(.isDraft == false and .isPrerelease == false and (.tagName | startswith("dealhunter-v"))) | .tagName')"; then
  write_status "$CURRENT" "" "error" "Could not read the private DealHunter GitHub release channel."; echo "Unable to read GitHub releases from $REPO."; exit 4
fi
LATEST="$(printf '%s\n' "$TAGS" | sed -n 's/^dealhunter-v//p' | sort -V | tail -n1)"
if [[ -z "$LATEST" ]]; then
  write_status "$CURRENT" "" "publishing" "GitHub is waiting for the first DealHunter release to finish publishing."; echo "No DealHunter release found yet."; exit 0
fi
if [[ ! "$LATEST" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  write_status "$CURRENT" "$LATEST" "error" "The newest GitHub release has an invalid version tag."; echo "Invalid release version: $LATEST"; exit 5
fi
LOWEST="$(printf '%s\n%s\n' "$CURRENT" "$LATEST" | sort -V | head -n1)"
if [[ "$LOWEST" == "$LATEST" ]]; then
  write_status "$CURRENT" "$LATEST" "current" "DealHunter $CURRENT is current. Automatic GitHub checks are enabled."; echo "Already current: $CURRENT (latest $LATEST)."; exit 0
fi
TMP="$(mktemp -d /tmp/dealhunter-update.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT
if ! as_osmii release download "dealhunter-v$LATEST" --repo "$REPO" --pattern dealhunter-update.zip --pattern dealhunter-update-manifest.json --dir "$TMP"; then
  write_status "$CURRENT" "$LATEST" "error" "GitHub release assets could not be downloaded."; echo "Could not download release assets."; exit 6
fi
test -s "$TMP/dealhunter-update.zip" && test -s "$TMP/dealhunter-update-manifest.json"
EXPECTED="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["sha256"])' "$TMP/dealhunter-update-manifest.json")"
MANIFEST_VERSION="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$TMP/dealhunter-update-manifest.json")"
[[ "$MANIFEST_VERSION" == "$LATEST" ]] || { write_status "$CURRENT" "$LATEST" "error" "Release manifest version did not match the GitHub tag."; echo "Manifest version mismatch."; exit 7; }
printf '%s  %s\n' "$EXPECTED" "$TMP/dealhunter-update.zip" | sha256sum -c -
mkdir "$TMP/stage"
unzip -oq "$TMP/dealhunter-update.zip" -d "$TMP/stage"
chmod 0755 "$TMP/stage/install-update.sh"
if ! DEALHUNTER_APP_ROOT="$APP_ROOT" bash "$TMP/stage/install-update.sh"; then
  write_status "$CURRENT" "$LATEST" "error" "DealHunter update failed its install or health check; the prior UI was restored."; echo "DealHunter install-update script failed."; exit 8
fi
echo "[$(date -Is)] DealHunter update to $LATEST completed successfully."
