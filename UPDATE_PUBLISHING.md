# Music Vault update publishing

Release channel: `Osm1i/music-vault-updates`.

The workflow in `.github/workflows/publish-music-vault-release.yml` assembles the versioned package, verifies archive integrity, syntax and checksums, regenerates the SHA-256 update manifest, and publishes the ZIP and manifest as a GitHub Release. The app updater reads the latest release through the public GitHub Releases API.

## Vanguard 9.4.0

- Uses the exact prepared package split into ordered chunks under `release-assets/velocity-9.4-b64/`.
- CI reconstructs the archive, verifies `SHA256SUMS_9_4_0.txt`, checks Python/JavaScript/Bash syntax, and runs the packaged smoke test before publishing.
- Adds a cache-first PWA shell with background refresh, lazy/async artwork, rendering containment for long lists, and visibility-aware status polling.
- Keeps private profile, library, stream and other API responses network-only.
- Fixes the public release channel to `Osm1i/music-vault-updates`, clears stale saved tokens, and re-enables hourly check/download.
- Update checking and downloading may run automatically, but installation remains an explicit user action in Music Vault. No unattended installation is enabled.
- Removes any older, competing auto-installer service from the 1.0.0 patch if present.

## Vanguard 9.2.0

The 9.2 release applies the 9.1 Velocity asset layer, then adds:
- A dedicated systemd install service for user-triggered updates.
- A restricted sudoers grant for starting only the update-check and update-install services.
- A route implementation that starts systemd units synchronously enough to return permission/start errors instead of detaching an unobserved sudo process.
- A progress UI that waits for the installed version to match the latest version, reports errors, and refreshes after success.
- Removal of CasaOS, GitHub repository and token configuration details from the visible Settings screen.
- Server-side default configuration for the release repository with no stored token.

## Data safety

Release packages must not contain music, SQLite databases, user profiles, playlists, favorites, EQ settings, server credentials or backup archives. Installers must preflight, back up changed code, verify checksums, restart the service, health-check and roll back if installation fails.

For future releases, add a preparation script or package chunk set, update the workflow's version recipe, update release notes, then update `release-assets/MUSIC_VAULT_RELEASE_VERSION.txt` last to trigger publishing.


## Vanguard 9.5.0

- Package source: `release-assets/velocity-9.5-b64/part-000.b64` through `part-010.b64`.
- CI reconstructs the exact package ZIP, verifies archive integrity and SHA-256 checksums, checks Python and JavaScript/Bash syntax, and runs 9.5 package regression checks before publishing.
- Adds redesigned Songs library, safe hold-to-remove with recoverable file quarantine, optimized Recent Added API, genre-aware Search and Radio, and compact Dynamic Island search-label fix.
- Installer uses exact v9.4 source fingerprints and zero-fuzz patches; it snapshots only app source/static files, rolls back on errors, and live-checks the service and new endpoints.
- Existing updater routes, GitHub release client, manifest format, systemd timer/install services and user-approved install flow remain untouched.
