# Music Vault v9.21.0 — Private profile libraries and faster loading

This release gives each family profile its own music library while safely sharing physical files when multiple profiles import the same track.

- Each profile sees only its own songs, albums, artists, search results and recently added music.
- Imports and duplicate imports are assigned to the importing profile.
- Streaming, artwork, lyrics, favorites, history, playlists and import queues are scoped to the active profile.
- Removing a song removes only that profile's ownership. Another profile's copy remains playable.
- Legacy tracks are assigned to their recorded importer once; future scans cannot silently restore removed ownership.
- Adds indexed profile ownership, per-profile status/recent caches, SQLite WAL/cache tuning and targeted indexes to speed up library queries.

The installer applies a source-baseline-checked patch with file-level backup and rollback. It does not replace the music database or music files, and preserves profiles, playlists, favorites, history, EQ, queue and USB settings.

Automated regression coverage includes cross-profile access, duplicate imports, shared-track deletion, playlists, favorites, history, streaming, lyrics, rescan and legacy migration.
