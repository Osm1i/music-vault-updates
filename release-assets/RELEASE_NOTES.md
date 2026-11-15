# Music Vault v9.26.2 — installer validation fix and full requested feature preservation

This is a corrective replacement for 9.26.0 and 9.26.1. The previous releases had independent installer defects:
- 9.26.0 escaped shell variables and did not resolve the application/package paths correctly.
- 9.26.1 still looked for `SHA256SUMS_9_26_0.txt`, while the release builder generated `SHA256SUMS_9_26_1.txt`. The installer therefore stopped during package validation.

This release corrects the checksum filename and adds an end-to-end installer simulation that executes the actual install script against a Music Vault-shaped app directory with mocked service and HTTP commands. It tests both a successful update and a forced live-verification failure that must restore the previous files.

## Requested Music Vault features preserved

- Android one-finger scrolling, pan and pinch-zoom compatibility from the earlier Android touch updates.
- Profile-specific Favorites: the heart fills red when favorited and returns to an outline when removed.
- Mini-player X: stops playback, clears the Up Next queue and saved player state, and hides the mini-player without deleting the song.
- Home Recently Added: compact, horizontal Top Picks-style album cards with square artwork, title/artist text and View All.
- Home recommendation cards: animated ambient lighting, color fields, light sweeps, floating music symbols, glowing rings, orbit effects and station equalizer details, with reduced-motion fallback.
- YouTube URL downloads: best available audio source selection, 12-way concurrent HLS/DASH fragments, 10 MiB HTTP chunks where supported and a 1 MiB buffer.
- Original Opus stream-copy remux is retained; this does not re-encode or reduce source audio quality.

The 9.26.2 installer is additive. It updates only the existing yt-dlp options dictionary, adds a separately versioned animation stylesheet and inserts its stylesheet reference in the Home template. It does not replace the consolidated app JavaScript, service worker, existing Android touch stylesheet, Recently Added stylesheet, database, music files or profile/playback data.

## Installer safety and verification

- Validates the exact versioned checksum file (`SHA256SUMS_9_26_2.txt`) before making changes.
- Verifies the existing Home renderer and mood/station card selectors.
- Backs up app.py, templates/index.html, the new stylesheet and installed-version marker.
- Restarts Music Vault once and checks live Home HTML, served CSS, downloader settings, playback JS hash, service worker hash and service health.
- On any failure, restores the backed-up app files and restarts the previous app.
- Writes the exact failing step, shell line, exit status and backup path to `data/updates/last-install-failure-9.26.2.txt`.

GitHub checks run Python regression tests, shell syntax validation, checksum and ZIP integrity checks, plus full installer simulations for success and automatic rollback. The release is marked ready only when all checks and GitHub publication succeed.
