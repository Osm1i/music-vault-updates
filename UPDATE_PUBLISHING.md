# Music Vault update publishing

Release channel: `Osm1i/music-vault-updates`.

The workflow in `.github/workflows/publish-music-vault-release.yml` assembles the versioned package from the ordered compressed archive chunks, applies the matching additive release-preparation scripts, verifies archive integrity and syntax, regenerates SHA-256 checksums, and publishes the ZIP and manifest.

## Vanguard 9.2.0

The 9.2 release applies the 9.1 Velocity asset layer, then adds:
- A dedicated systemd install service for user-triggered updates.
- A restricted sudoers grant for starting only the update-check and update-install services.
- A route implementation that starts systemd units synchronously enough to return permission/start errors instead of detaching an unobserved sudo process.
- A progress UI that waits for the installed version to match the latest version and refreshes after success.
- Removal of CasaOS, GitHub repository and token configuration details from the visible Settings UI.
- Server-side default configuration for the release repository with no stored token.

## Data safety

Release packages must not contain music, SQLite databases, user profiles, playlists, favorites, EQ settings, server credentials or backup archives. The installer must preserve these items, back up changed code, verify checksums, restart the service, health-check and roll back if installation fails.

For future releases, add a preparation script, update the workflow's version recipe, update release notes, then update `release-assets/MUSIC_VAULT_RELEASE_VERSION.txt` last to trigger publishing.
