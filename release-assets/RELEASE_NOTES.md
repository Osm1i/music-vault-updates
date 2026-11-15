# Music Vault v9.21.0 — Private profile libraries and faster browsing

This release gives every Music Vault family profile its own music collection while retaining shared audio files safely.

Changes:
- Tracks are associated with the profile that imports them. Songs, albums, artists, search, artwork, streaming, lyrics, Apple Music inventory, import queues, playlists, favorites and listening history are scoped to the active profile.
- Duplicate imports attach the existing catalog track to the importing profile rather than duplicating the audio file.
- Removing a shared track or album removes only the active profile's ownership. The underlying audio stays available while another profile still owns it.
- Legacy catalog tracks receive a safe one-time owner migration; profiles that deliberately remove a track are not silently re-added on later restarts.
- Pending lyrics remain profile-owned, and profile-specific access checks protect track streaming and lyric endpoints.
- Improves database responsiveness with WAL mode, a busy timeout, useful library/ownership indexes, bounded caches and profile-aware cache invalidation.
- Uses a versioned source patch against the verified 9.20 source baseline. The installer refuses mismatched source, backs up each changed application file, runs profile-isolation regression tests, restarts once, checks live APIs/schema and rolls back source files if validation fails.
- Music files, the existing database records, credentials, USB configuration, update services, queue contents, EQ settings and profiles are not bundled in this update. The ownership relation and indexes are added to the existing database on first start.

Validation: source-patch dry run, Python compilation, JavaScript syntax, inline-script checks, profile API checks, regression tests covering ownership, deduplication, shared-track deletion, lyrics, streaming, playlists, favorites, history and rescans, SHA-256 checks and ZIP integrity checks passed locally. GitHub Actions rechecks release checksums, shell/Python syntax and payload boundaries. The server installer repeats profile regression tests and live API checks at installation time.
