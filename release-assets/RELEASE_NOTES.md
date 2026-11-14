# Music Vault v9.11.0 — Profile Studio

A focused overhaul of **Who's Listening?** built around fast, clear profile selection.

- Replaces the oversized stacked profile rows with a compact adaptive grid: three columns on wide screens, two on phones, and one on very narrow screens.
- Gives each person a clear avatar, readable name, and a distinct current-listener state.
- Makes the current profile obvious without adding a confirmation step.
- Keeps the existing per-profile edit action attached to each person's card.
- Keeps the existing Add Profile action as a simple tile. It does not add logins, passwords, PINs, registrations, or account switching.
- Removes the duplicate empty "Choose your profile" area, repeated "Your listening identities" heading, and the "Customize current" / "Replay intro" clutter from this screen.
- Preserves the existing family profile API and all original profile select, add, and edit handlers.
- Scoped to the Who's Listening screen only; the Music Vault backend, database, library, playlists, favorites, queue, audio files, player, background playback, and EQ are untouched.
- Includes responsive, keyboard-focus, and reduced-motion styling checks, SHA-256 verification, a database snapshot, service/API/static-asset health checks, and automatic rollback.

**Install:** Music Vault → Settings → Update Center → Check now → Install update.

No profile or music data is migrated, rewritten, or deleted by this release.