#!/usr/bin/env bash
set -Eeuo pipefail
# Baseline release only. It establishes the release channel at the already-installed version.
APP_ROOT="${MUSIC_VAULT_APP_ROOT:-/opt/music-vault}"
EXPECTED_VERSION="8.12.1"
CURRENT_VERSION="$(cat "$APP_ROOT/data/installed_version.txt" 2>/dev/null || true)"
if [ "$CURRENT_VERSION" = "$EXPECTED_VERSION" ]; then
  echo "Music Vault $EXPECTED_VERSION is already installed. Baseline release: no changes made."
  exit 0
fi
echo "Refusing to apply the baseline-only package to version '${CURRENT_VERSION:-unknown}'." >&2
echo "This release exists only to establish the updater channel; a real versioned update is required." >&2
exit 2
