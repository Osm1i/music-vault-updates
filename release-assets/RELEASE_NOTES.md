# Music Vault v9.27.0 — Reliability Center, smarter downloads, library intelligence and playlist controls

## Reliability Center
- Adds a Settings dashboard for app-service status, SQLite size, free storage, queue counts, backup age and library diagnostics.
- Creates daily SQLite online backups, verifies each snapshot with `PRAGMA integrity_check`, retains the newest 10, and offers a manual backup/download action.
- Library diagnostics report duplicate content-hash groups, same-metadata groups and missing file references.
- Safe re-index triggers the app's existing scanner. It does not move, delete or re-encode audio files.

## Smarter YouTube downloads
- Keeps `bestaudio/best` as the source selector and retains existing metadata/artwork processing.
- Adapts HLS/DASH fragment concurrency to CPU and available memory, adds retry/backoff for transient HTTP, fragment and extractor failures, and enables partial-download continuation.
- Preserves the stream-copy Opus remux path; no forced lossy re-encoding is introduced.
- Detects YouTube's "Sign in to confirm you're not a bot" response and shows a precise explanation instead of a generic failure.
- Supports a user's own Netscape-format `cookies.txt` file at `/opt/music-vault/data/youtube-cookies.txt` (or `MUSICVAULT_YOUTUBE_COOKIES`). The file is private, set to mode 600, never included in the release, and never exposed by the app.
- YouTube's verification is not bypassed. When YouTube challenges a request, the user must provide their own signed-in browser cookies; cookies expire and should never be shared.

## Playlist deletion
- Adds a Delete action to each profile-owned playlist with a confirmation prompt.
- The backend validates playlist ownership against the active profile and deletes only playlist rows and their join records.
- Songs remain in the shared music library; audio files are never deleted.

## Preservation and safety
- Existing Android touch fixes, red favorite heart, mini-player X, Recently Added Top Picks layout, animated recommendation cards, playback JS and service worker are preserved.
- Database, profiles, favorites, listening history and downloaded audio are not replaced.
- The installer backs up changed application files and the installed-version marker, performs live checks, and restores the previous files on any failed verification.
- Both the feature regression suite and full installer success/forced-failure rollback simulation must pass before GitHub publishes the ZIP.
