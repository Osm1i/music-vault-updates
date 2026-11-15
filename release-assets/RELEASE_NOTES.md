# Music Vault v9.24.0 — Recently Added layout and faster URL downloads

This release fixes the blank Home Recently Added area and improves YouTube URL download throughput while preserving the established music quality and player features.

- Fixes the mobile CSS specificity conflict that forced the new Recently Added album cards into an incompatible horizontal rail. The Home feed now displays a responsive two-column album grid on phones and an adaptive grid on larger screens.
- Repairs the Recently Added “View all” action so it opens the Library’s Albums view directly.
- Keeps the existing Listen Now, New, Radio, Library and Search routes and the More dock behavior intact.
- Suppresses only the exact Safari detached-DOM NotFoundError (“The object can not be found here.”) from becoming a misleading Home error banner. Other Home errors remain visible.
- Increases yt-dlp HLS/DASH fragment concurrency to 8, adds 10 MiB HTTP chunking where supported, and increases the download buffer to 1 MiB. yt-dlp documents concurrent fragments as defaulting to 1; HTTP chunking is documented as experimental and may help with server-side throttling.
- Keeps the existing best-audio source selection, source codec, metadata/artwork processing and remux-without-re-encoding behavior.

The installer backs up app.py, templates/index.html, the new static assets, and the installed-version marker. It makes only a targeted addition to the existing yt-dlp options, attaches separately versioned Home repair assets, restarts once, and checks the live Home page, JavaScript/CSS, Recently Added API and primary navigation markup. If a live validation fails, it restores the backed-up files and restarts the previous app.

Automated checks cover responsive grid CSS, Recently Added routing, exact benign error filtering, primary tab markup retention, yt-dlp options, idempotency, Python/JavaScript/shell syntax, and unchanged existing playback JavaScript, styles, service worker and 9.23 player controls. Physical-device Home layout and actual download speed should still be confirmed after installation.
