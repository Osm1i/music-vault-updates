# Music Vault Vanguard 9.5.1 — Recent Added Cache Fix

## Corrected 9.5.0 installation failure
- Declare the shared Recent Added cache at module scope inside its endpoint, fixing the `UnboundLocalError` that caused HTTP 500 during live installation.
- Reset cache fields during track removal rather than clearing the dictionary, so subsequent requests retain the required cache keys.
- Avoid rerunning expensive grouping on every request when a library has fewer albums than the requested page size.
- Run cold-cache, warm-cache, and invalidation/refresh regression tests in CI.
- The installer now calls Recent Added twice after restart and validates both responses before committing the update; failed health checks still trigger rollback.

## Included Vanguard 9.5.0 features
- Redesigned Library → Songs with track metadata and existing playback, queue, favorite and playlist actions.
- Press-and-hold / More / context-menu song removal with confirmation and recoverable hidden quarantine for the audio and supported sidecars.
- Faster Recent Added using a bounded endpoint and shared cache.
- Search mood categories and Radio stations backed by embedded genre tags, with conservative fallback matching.
- Dynamic Island search text is hidden in compact mode.

## Preservation
- The existing public GitHub Releases updater remains unchanged: same release API, ZIP + manifest, SHA-256 verification, scheduled checks/downloads, user-approved install, systemd install service, backups and rollback.
- No updater routes, updater services/timers, credentials, music, databases, profiles, playlists, favorites, history, EQ, queue data or USB configuration are included or replaced.

Open Music Vault → Settings → Update Center → Check for updates → Install update. Installation remains user-approved.
