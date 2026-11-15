# Music Vault v9.17.0 — Android Touch Repair + Installer Recovery

This release supersedes the failed 9.16.0 attempt with a simpler, independently validated installer and Android-only UI patch.

- Fixes Android/Samsung Galaxy touch targeting in the floating Bottom Island, player controls, primary tabs, More, and Search.
- Applies Android-only pointer-event and touch-action rules; key controls have 44px minimum hit targets and 52px for the collapsed primary controls.
- Restores an 8px Android bottom inset for the dock while leaving iPhone/iPad and desktop styling unchanged.
- Uses an idempotent patcher: it verifies both HTML markers and the service-worker shell before changing anything, and safely accepts the 9.14.0, 9.15.0, or rolled-back 9.16.0 baseline.
- Updates the service-worker cache key and pre-cache list so Android Home Screen installs receive the new stylesheet.
- Takes a SQLite online backup and source-file backups; verifies the live home page, CSS, and service-worker responses; automatically rolls back changed UI assets on any failed check.
- Does not restart Music Vault. Playback, EQ, profiles, playlists, queue, database content, USB configuration, and music files are not migrated or overwritten.

Validation: checksum verification, Python compilation, shell syntax check, Android touch regression tests, idempotency tests, and a full temporary-install simulation passed. A physical Galaxy S26 was not available for direct device testing.