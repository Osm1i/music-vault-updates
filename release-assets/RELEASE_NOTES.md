# Music Vault v9.16.0 — Android / Galaxy Touch Compatibility

A focused mobile interaction patch for Android Chrome-installed Music Vault, including Samsung Galaxy devices.

- Restores the Android bottom-island clearance to 8px above the device inset. This offsets the 8px downward dock move introduced in 9.15.0 while leaving iPhone/iPad styling unchanged.
- Adds Android-only hit-testing rules for the floating player and bottom navigation so interactive layers receive taps consistently.
- Normalizes touch behavior and provides 44px minimum hit areas for player buttons, with 52px minimum height for bottom navigation targets.
- Updates the page asset URLs and service-worker cache so installed Android Home Screen apps receive the new stylesheet.
- Leaves playback handlers, background audio, EQ, library, playlists, profiles, queue, database rows and music files unchanged.
- Uses source-file backups and an online SQLite backup snapshot before patching; verifies the served home page, stylesheet and service worker, with rollback on failed checks.
- Does not restart Music Vault, avoiding playback interruption.

Validation: automated regression tests and the 9.15.0-to-9.16.0 source-patch simulation passed. A physical Galaxy S26 was not available for direct device testing.