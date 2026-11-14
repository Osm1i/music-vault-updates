# Music Vault v9.12.0 — Who's Listening? Overhaul

This release **replaces the old profile chooser visually** with a new, self-contained full-screen selection experience. It does not merely add another CSS layer to the previous chooser.

- New compact Profile Studio surface with a simplified heading, short guidance, and an adaptive two-column profile grid on phones.
- Saved family members load from the existing `/api/family` endpoint; no separate accounts or password system is introduced.
- Selecting a person uses the existing `/api/profile/active` route and refreshes into that listener's existing Music Vault space.
- Profile avatars are reused from the existing chooser when available; otherwise a simple initials treatment is shown.
- The active listener is marked clearly.
- Add Person and Edit actions forward to the existing Music Vault controls rather than implementing a new profile database or new account flow.
- Removes the previous guessed-style 9.10/9.11 script layers from the template and replaces them with one dedicated Profile Studio renderer.
- Does not modify `app.py`, the SQLite database, profile records, playlists, favorites, history, queue, audio files, player, background playback, or EQ.
- Includes a read-only database snapshot, template backup, SHA-256 verification, JavaScript/Bash syntax checks, existing API/static-asset health checks, and rollback on failed installation.

**Install:** Music Vault → Settings → Update Center → Check now → Install update.

No passwords, PINs, registration, or account switching. The old profile handlers remain the source of truth for Add and Edit.