# Music Vault v9.9.0 — Classic Profiles Restored

- Removes the private username/password account system and Secure Sign In interface introduced in 9.8.0.
- Restores the original Music Vault startup and profile-picker flow, with the shared Library and existing family profiles.
- Keeps the stable 9.6 performance, library, playback, background playback, and EQ behavior, along with the 9.7 responsive presentation.
- Removes only the 9.8 account startup hook, sign-in stylesheet/script, and account helper module.
- Creates a source snapshot and a SQLite database snapshot before installation; the update does not alter or migrate the database and does not drop any tables or rows.
- Existing profiles, playlists, favorites, listening history, queue data, and music files remain in place.
- Preserves the GitHub Update Center and its user-approved install flow.
- Includes regression tests, SHA-256 verification, service health checks, and rollback if the restored app does not start correctly.

**Install:** Music Vault → Settings → Update Center → Check for updates → Install update.

No music files are moved, copied, or deleted.