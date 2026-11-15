# Music Vault v9.23.0 — Favorite hearts and mini-player clear control

This update adds the two player controls requested for the Music Vault mini-player.

- Favorite hearts turn filled red when the song is saved to the active listening profile.
- Tapping the same heart again removes the favorite and returns it to the neutral outline.
- The mini-player and expanded Now Playing heart stay in sync with the profile's existing Favorites API.
- Visible song-list hearts retain the saved state after library views refresh and after switching listening profiles.
- Adds an X beside the mini-player heart. Pressing it stops audio, clears the current playback queue and saved player state, resets Now Playing, and hides the mini-player until another song is played.
- Clearing playback does not delete music files, library records, or saved Favorites.

The installer backs up the template, the two new player-control assets, and the installed-version marker. It applies an idempotent patch, restarts once to refresh Flask/Jinja, verifies the live HTML/CSS/JavaScript and service health, and restores the backed-up files if validation fails.

The patch does not modify app.py, the existing playback bundle, the service worker, the music database, profiles, playlists, listening history, EQ, or USB settings. Automated checks cover favorite-state wiring, the clear-X behavior, idempotent installation, JavaScript/shell syntax, and unchanged backend/playback/service-worker files. Actual device interaction still needs confirmation after installation.
