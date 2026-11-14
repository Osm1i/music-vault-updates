# Music Vault v9.14.0 — Profile Screen Recovery

Emergency recovery for users blocked by the additional Who's Listening overlay introduced in v9.12/v9.13.

- Removes the injected v9.10/v9.11/v9.12/v9.13 profile chooser JavaScript and CSS references from the app template.
- Removes the corresponding stale static assets so a second Who's Listening overlay cannot be loaded.
- Restores the original native Music Vault profile selector and its original profile-selection actions.
- Leaves the Intro / Enter Your Vault animation and flow unchanged.
- No replacement overlay or new profile UI is injected in this recovery release. The priority is restoring access to the working app.
- Preserves existing family profiles, profile metadata, playlists, favorites, listening history, queue, tracks, and music files.
- Does not modify `app.py`, SQLite tables/rows, playback, background playback, EQ, or the library.
- Creates a source/template backup and SQLite online-backup snapshot before changes; includes SHA-256 verification, service/home/status/family API checks, stale-asset checks, and rollback that restores the previous template and assets.

**Install while the UI is blocked:** use the direct Windows CMD SSH command in the release instructions, or use Music Vault's Update Center if it becomes accessible.

This is an access recovery release, not the final visual redesign.