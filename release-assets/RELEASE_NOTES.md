# Music Vault v9.13.0 — Single Who's Listening Screen

This is a corrective release for the v9.12 profile-picker problem.

- Hides the original Music Vault profile chooser while the replacement is active, so users see only one Who's Listening screen.
- Shows the replacement only when the existing native profile chooser is actually open; it does not trigger on the startup introduction.
- Removes the v9.12 forced `window.location.reload()` after profile selection. This avoids forcing the app back through its startup intro.
- Uses the existing profile card's click handler to select a listener; no second profile API or new account mechanism is introduced.
- Add and Edit temporarily return control to the existing Music Vault forms and handlers, then restore the replacement chooser after those forms close.
- Removes the previous v9.12 script and stylesheet references and replaces them with one v9.13 selector.
- No password, PIN, registration, or separate account flow.
- Does not modify `app.py`, the SQLite database, profile records, playlists, favorites, listening history, queue, music files, playback engine, background playback, or EQ.
- Includes a database snapshot, template backup, SHA-256 verification, JavaScript/Bash syntax checks, home/status/family API checks, static-asset checks, and automatic rollback on failed installation.

**Install:** Music Vault → Settings → Update Center → Check now → Install update.

The startup introduction is left untouched; this release only changes the Who's Listening selector.