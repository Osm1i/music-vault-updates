# Music Vault v9.15.0 — Bottom Island Position Adjustment

A small positioning-only refinement to the floating mini-player and bottom navigation island.

- Drops the combined Bottom Island 8px lower while keeping the iPhone safe-area inset intact.
- Aligns the historical CSS rules and both runtime JavaScript position controllers to the same bottom offset, preventing one controller from pulling the island back up.
- Bumps the consolidated CSS/JavaScript asset URLs and service-worker cache key so clients receive the corrected layout.
- Leaves player controls, navigation handlers, playback, background playback, EQ, library, playlists, profiles, queue, database rows, and music files unchanged.
- Uses an online SQLite backup snapshot and source-file backups before patching; verifies the home page and served CSS/JavaScript/service-worker assets, with rollback on failed checks.
- Does not restart Music Vault, avoiding playback interruption.
