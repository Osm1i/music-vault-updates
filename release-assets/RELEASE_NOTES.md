# Music Vault v9.18.0 — Update Installer Recovery + Android Touch

This release changes the update method after the 9.16.0 and 9.17.0 installer failures.

- Removes brittle service-worker source rewriting from the Android touch update. The service worker is left byte-for-byte unchanged.
- Uses an Android-only stylesheet and idempotent HTML registration; it does not alter player handlers, navigation JavaScript, or the service-worker shell.
- Uses staged, numbered installer logging so a failed preflight is visible rather than reported only as a generic subprocess error.
- Removes the brittle hard-coded installed-version gate. The installer validates the live Music Vault layout, package checksums, service health, and served home page before patching.
- Backs up only the HTML template, the new stylesheet if already present, and the version marker. Automatic rollback restores those files if HTTP or asset verification fails.
- Does not restart Music Vault. Database, profiles, playlists, queue, EQ, music files, and playback processes are not changed.

Validation passed locally: ZIP integrity, SHA-256 checks, Python compilation, Bash syntax, Android CSS/HTML regression tests, idempotent repeat-install simulation, and verification that the service-worker file remains unchanged. A physical Galaxy S26 has not been directly tested.