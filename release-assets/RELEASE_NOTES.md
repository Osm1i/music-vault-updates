# Music Vault v9.24.1 — Installer compatibility and Home refresh recovery

This maintenance release corrects the 9.24.0 installer so it does not require an optional Node.js executable on CasaOS. Music Vault's YouTube extraction supports Deno as its preferred JavaScript runtime; server-side browser JavaScript syntax checking is therefore removed from the installer and remains covered by the GitHub build.

- Fixes the 9.24.0 installation failure caused by requiring Node on the CasaOS host even when Deno is the configured YouTube runtime.
- Improves Home Recently Added recovery: when album cards are absent, it retries the existing Music Vault 7.10 album renderer a few times after load and when returning to Listen Now.
- Keeps the responsive two-column Recently Added grid on phones.
- Makes Recently Added “View all” route directly to Library → Albums using the app's actual `mvGoPage` and `mvLibraryTab` functions.
- Suppresses only the exact Safari detached-DOM NotFoundError from creating the misleading Home error banner; unrelated errors remain visible.
- Keeps the 9.24.0 yt-dlp throughput options: 8 concurrent HLS/DASH fragments, 10 MiB HTTP chunks where supported, and a 1 MiB buffer, preserving best available source audio and existing metadata processing.
- Leaves Listen Now, New, Radio, Library, Search, and More navigation intact.

The installer now reports the exact failed step, line and exit status if anything goes wrong. It backs up app.py, templates/index.html, the new Home assets and the installed-version marker, restarts once, checks Home HTML/assets, primary tabs, the Recently Added API and service health, and restores the backed-up files if validation fails.

Automated GitHub tests cover the real Music Vault markup/API anchors, Home rendering retry, Albums navigation, exact benign error filtering, download options, idempotency, syntax and preservation of the existing player, service worker, music database and 9.23 player controls. Physical device behavior and actual download speed still require confirmation after installation.
