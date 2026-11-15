# Music Vault v9.26.1 — 9.26 installer shell-expansion fix

This maintenance release fixes the 9.26.0 installer failure. The 9.26.0 shell script escaped variable expansion in APP_ROOT, SERVICE, PORT and the installer-directory expression. Bash therefore treated the application root as a literal string instead of resolving `/opt/music-vault`, causing the initial app-layout validation to exit before applying the update.

- Corrects Bash variable expansion for the app root, service name, port and staged package directory.
- Adds build-time assertions that reject escaped shell variable expansion and verify APP_ROOT resolves correctly.
- Keeps the 9.26.0 animated mood/station cards and reduced-motion fallback.
- Keeps YouTube HLS/DASH fragment concurrency at 12, 10 MiB HTTP chunks where supported and the 1 MiB buffer.
- Preserves `bestaudio/best` source selection, metadata/artwork processing and FFmpeg Opus stream-copy remuxing; no lower-quality re-encoding is introduced.

The corrected installer validates the existing app and package before changing files, backs up app.py, templates/index.html, the new stylesheet and version marker, then applies the additive patch and performs live service/asset checks. If a live check fails, it restores the saved files and restarts the previous app.

Automated checks test shell variable expansion, package checksum/integrity, Python patch tests, installer syntax, idempotent patching, and preservation of the existing Home/player JavaScript and service worker. The release is published only after the GitHub workflow completes successfully.
