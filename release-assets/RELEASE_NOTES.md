# Music Vault Vanguard 9.5.0 — Library Experience + Genre Intelligence

## Library → Songs
- Rework the Songs view into a clear, sortable track library with artwork, track/artist/album metadata, genre/file details, duration and quick actions.
- Keep playback, queue, favorites and playlist actions connected to the existing handlers.

## Remove an incorrect version safely
- Press and hold a song, use the context menu, or tap More to request removal.
- Show a confirmation before removing the track from the catalog and personal references.
- Move the audio file and supported lyric/subtitle sidecars into a hidden recoverable .trash folder rather than permanently deleting them.
- Refuse paths outside the configured music root and restore moved files if the database operation fails.

## Faster Recent Added
- Add a bounded recent-albums endpoint using folder/path ranges and a short shared server cache.
- Keep the existing Recent Added presentation while avoiding repeated full-library grouping and pagination.

## Search and Radio
- Read embedded genre tags into the catalog and incrementally backfill existing tracks.
- Make Search mood categories and Radio genre stations query actual genre metadata, with conservative title/artist fallback for tracks that have no genre tag.
- Radio category searches are server-side rather than limited to only the newest locally loaded tracks.

## Dynamic Island polish
- Hide the search text label in compact mode while retaining the icon and corrected alignment.

## Updater and data safety
- Preserve the existing public GitHub Releases update method for `Osm1i/music-vault-updates`.
- Keep the existing ZIP + manifest + SHA-256 verification, scheduled checks/downloads, systemd install path, backups, rollback and user-approved Install action.
- The release payload does not replace updater routes, updater services/timers, credentials, user databases, profiles, playlists, history, favorites, EQ settings, queue data, USB configuration or music files.
- No music or database content is included.

Open Music Vault → Settings → Update Center → Check for updates → Install update. Installation remains user-approved.
