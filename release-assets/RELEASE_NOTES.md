# Music Vault v9.28.0 — correct single-track album detection

## Album metadata fix
- Treats generic album placeholders such as `Single`, `Singles`, `Unknown Album`, blank and similar "no album" labels as missing metadata.
- Uses the track title as the album name for standalone tracks, so each single appears as its own album instead of many unrelated tracks being grouped under "Single".
- Keeps genuine album tags (for example, an actual album name) unchanged.
- Applies the same fallback to files imported from uploads and URL downloads.

## Existing library cleanup
- Runs a one-time, non-destructive database migration that changes existing placeholder album labels to each track's title.
- Splits distinct single tracks into separate Albums and Recently Added cards even when their files remain in a legacy shared `Artist/Single` directory.
- Album detail and artwork lookups are scoped to the selected album, preventing other tracks in that legacy folder from appearing in the wrong album.
- Does not move, rename or delete any audio files or sidecars.

## Preservation and safety
- Keeps playback, playlists, favorites, the mini-player, Android touch support, Top Picks layout, Home animations and YouTube download settings unchanged.
- The installer backs up app.py and the SQLite database, verifies Albums and Recently Added live API responses, fingerprints protected UI assets, and restores the previous app/database on failed checks.
- GitHub CI runs metadata regression tests plus successful-install and forced-rollback simulations before publishing.
