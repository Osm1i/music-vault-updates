# Music Vault v9.10.0 — Family Profile Picker

- Removes the extra Owner profile created by the 9.8 account migration, but only when the database proves it is the newest synthetic profile alongside the two original family profiles.
- Preserves both original profile records and refuses cleanup if Owner contains saved playlists, favorites, listening history, or Apple Music library data.
- Removes the unused 9.8 private-account/password table, profile-library migration table, admin trigger, and session secret. Music Vault remains password-free and uses the original shared family-profile flow.
- Refreshes the “Who's Listening?” chooser with a cleaner dark-and-champagne layout, readable profile tiles, larger tap targets, and a responsive grid that adapts as the family grows.
- Keeps the existing one-tap profile selection and existing Add Profile action. No registration, login, password, or extra account steps are added.
- Does not replace the app backend, player, playback engine, background playback, 10-band EQ, library, playlists, favorites, or listening history.
- Creates a full source and SQLite snapshot before installation. Includes profile-count verification, static-asset checks, SHA-256 verification, and automatic rollback if health checks fail.

**Install:** Music Vault → Settings → Update Center → Check now → Install update.

No audio files are moved or deleted.