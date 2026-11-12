# Music Vault Vanguard 9.4.0 — Instant Shell + Update Center Repair

## Faster startup and navigation
- Serve a previously cached app shell and static assets immediately, refreshing them quietly in the background.
- Version the service-worker registration to 9.4.0 so the new cache policy is picked up on the next app launch.
- Lazy-load off-screen album art, decode images asynchronously, and prioritize above-the-fold artwork.
- Defer off-screen rendering for long album grids and track lists.
- Pause dashboard status polling while the app is hidden; reduce idle polling from 3 seconds to 15 seconds and keep active download progress at 5 seconds.
- Keep API responses, personal profile data, library data and audio streams network-only.

## GitHub Update Center repair
- Keep the existing GitHub Releases API, ZIP + manifest assets, SHA-256 verification, backup, install and rollback method.
- Pin the public channel to `Osm1i/music-vault-updates` and clear a stale saved token so public GitHub requests are unauthenticated.
- Re-enable the original hourly check/download timer. Installing still requires the user's explicit approval inside Music Vault; no unattended install is added.
- Retain systemd-backed check/install services and visible install success/failure feedback.
- Remove the competing unattended auto-installer integration if it was installed previously.
- Hide CasaOS admin details and personal GitHub repository/token fields from public Settings.

## Preserved and included fixes
- Retain active/stuck URL download cancellation without touching unrelated queue items or completed files.
- Preserve the existing audio player, background playback, EQ, family profiles, playlists, favorites, history, library, USB configuration and music folders.
- No databases, music, personal profiles, playlists, or credentials are included in this release package.

## Install
Run `INSTALL_MUSIC_VAULT_9_4_0_PERFORMANCE.cmd` from Windows with this ZIP in the same folder. The installer backs up changed code and updater files, preflights patches, restarts Music Vault and runs post-install health checks with rollback on failure.

The repository `Osm1i/music-vault-updates` must be public for token-free GitHub release checks. This release does not change the repository owner or update method.
