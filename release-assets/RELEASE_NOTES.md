# Music Vault Vanguard 9.6.0 — Faster Loading + Album Removal

## Faster first load
- Reduce Listen Now's blocking data to a bounded recent set (24 recent albums and 120 recent tracks) and paint it before profile extras load.
- Playlist cards load four-track previews; full playlist contents are fetched only when a playlist is opened.
- Keep a short profile-scoped Home cache and invalidate it when switching profiles.
- Batch Recent Added folder reads, use SQL-backed album grouping/pagination, add a short status cache, and keep Home/library artwork lazy and asynchronous.
- Preserve all existing player, navigation, profile, favorites and playlist interactions.

## Remove an entire album safely
- Hold an album card for about 0.7 seconds, use its More menu, or right-click on desktop.
- Show a confirmation including the album and track count.
- Move its audio files and supported lyric sidecars into a hidden, recoverable `.trash/MusicVaultRemoved/album-*` folder with a manifest recording original paths.
- Remove catalog rows and associated playlist, favorite, history and Apple-library match references transactionally. If a move or database operation fails, restore the moved files and roll back.
- The existing single-song hold-to-remove behavior remains available.

## Updater and data safety
- This is an incremental update for the exact Music Vault 9.5.1 source baseline.
- Keep the existing public GitHub Releases updater for `Osm1i/music-vault-updates`: same ZIP + manifest format, SHA-256 verification, scheduled check/download, systemd install service, backup/rollback and user-approved Install action.
- Do not replace updater routes, updater JavaScript, updater services/timers, credentials, personal database, profiles, playlists, favorites, history, EQ settings, queue data, USB configuration or music files.
- No personal music or database content is included.

Open Music Vault → Settings → Update Center → Check for updates → Install update. Installation remains user-approved.
