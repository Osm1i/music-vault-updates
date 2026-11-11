#!/usr/bin/env bash
set -Eeuo pipefail
REPO="${DEALHUNTER_GITHUB_REPO:-Osm1i/music-vault-updates}"
APP_HOME="/home/osmii"
GH_CONFIG_DIR="$APP_HOME/.config/gh"
USER="osmii"
BUNDLE="$(cd "$(dirname "$0")/.." && pwd)"
run_user(){ runuser -u "$USER" -- env HOME="$APP_HOME" GH_CONFIG_DIR="$GH_CONFIG_DIR" "$@"; }
if ! command -v gh >/dev/null 2>&1; then
  apt-get update -y
  apt-get install -y gh
fi
if ! run_user gh auth status --hostname github.com >/dev/null 2>&1; then
  echo
  echo "ONE-TIME GITHUB SIGN-IN: open https://github.com/login/device and enter the code shown next."
  echo "DealHunter uses its own release-assets folder and dealhunter-v* release tags. Music Vault assets remain separate."
  run_user gh auth login --hostname github.com --git-protocol https --web
fi
run_user gh auth setup-git
TMP="$(mktemp -d /tmp/dealhunter-gh-seed.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT
chown "$USER":"$USER" "$TMP"
run_user gh repo clone "$REPO" "$TMP/repo"
mkdir -p "$TMP/repo/dealhunter-release-assets/package" "$TMP/repo/.github/workflows"
cp -a "$BUNDLE/github-channel/dealhunter-release-assets/." "$TMP/repo/dealhunter-release-assets/"
cp "$BUNDLE/github-channel/.github/workflows/publish-dealhunter-release.yml" "$TMP/repo/.github/workflows/publish-dealhunter-release.yml"
chown -R "$USER":"$USER" "$TMP/repo"
run_user git -C "$TMP/repo" config user.name "DealHunter Release Bot"
run_user git -C "$TMP/repo" config user.email "dealhunter-release-bot@users.noreply.github.com"
run_user git -C "$TMP/repo" add dealhunter-release-assets .github/workflows/publish-dealhunter-release.yml
if ! run_user git -C "$TMP/repo" diff --cached --quiet; then
  run_user git -C "$TMP/repo" commit -m "Publish DealHunter 8.0 Ultimate Command Center release channel"
  run_user git -C "$TMP/repo" push origin HEAD
else
  echo "DealHunter release source is already up to date in $REPO."
fi
install -m 0755 "$BUNDLE/package/check-dealhunter-update.sh" /usr/local/sbin/dealhunter-update-check.sh
install -m 0755 "$BUNDLE/package/install-update.sh" /usr/local/sbin/dealhunter-install-update.sh
cat > /etc/systemd/system/dealhunter-update.service <<'UNIT'
[Unit]
Description=Check DealHunter private GitHub release channel
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/dealhunter-update-check.sh
UNIT
cat > /etc/systemd/system/dealhunter-update.timer <<'UNIT'
[Unit]
Description=Check DealHunter GitHub releases every 15 minutes

[Timer]
OnBootSec=3min
OnUnitActiveSec=15min
Persistent=true
RandomizedDelaySec=90s

[Install]
WantedBy=timers.target
UNIT
systemctl daemon-reload
systemctl enable --now dealhunter-update.timer
systemctl start dealhunter-update.service || true
echo "GitHub release channel configured for $REPO."
echo "Automatic checks: every 15 minutes."
echo "GitHub Actions workflow: Publish DealHunter mobile release."
echo "Verify with: systemctl status dealhunter-update.timer --no-pager"
