# Music Vault v9.19.0 — Fix Flask Template Cache During Updates

This release fixes the live-validation failure in 9.18.0.

Root cause: Music Vault's Flask/Jinja process can keep the compiled home-page template in memory. The 9.18.0 installer changed the template file and immediately checked the live page without refreshing that template cache, so it could roll back a correct file change.

Changes:
- Applies the Android-only touch stylesheet and Android user-agent class.
- Restarts Music Vault once after the template update to clear the in-memory Flask/Jinja template cache.
- Waits up to 30 seconds for the systemd service and home page to return.
- Verifies that the served home page contains the new stylesheet and Android detector.
- Verifies that the live served CSS bytes exactly match the installed stylesheet.
- Adds explicit installer stage/error logging so a failure identifies the step that failed.
- Keeps automatic rollback: if restart or live checks fail, restores the original template, stylesheet and version marker, then restarts the restored app.
- Leaves the service worker, playback JavaScript, database, profiles, playlists, queue, EQ and music files untouched.

Validation: ZIP integrity, SHA-256 verification, Python compilation, shell syntax, Android touch regression tests, idempotency tests, and installer-order checks passed. The package now refreshes the template cache before checking the live page. A physical Galaxy S26 has not been directly tested.