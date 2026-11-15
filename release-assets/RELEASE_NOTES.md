# Music Vault v9.26.0 — Ambient Home cards and faster YouTube downloads

This release gives the artwork-free Home recommendation cards a more animated, living presentation and tunes YouTube download throughput without lowering source-audio quality.

## Home card animations

- Adds slow-moving ambient color fields to the large “Playlists Made for You” mood cards.
- Adds a soft light sweep, floating symbols, expanding halo rings and orbiting accent lights.
- Gives each mood and station a distinct accent palette.
- Adds a small animated equalizer accent to “Stations for You” cards.
- Keeps the cards' existing tap targets, click handlers, swipe rails, content, and section layout intact.
- Uses transform/opacity-based decorative effects and includes a `prefers-reduced-motion` fallback.
- Does not animate album artwork, Recently Added cards, the player, or bottom navigation.

## YouTube download throughput and audio quality

- Increases yt-dlp HLS/DASH fragment concurrency from 8 to 12.
- Retains 10 MiB HTTP chunking where the source server supports range/chunk downloads.
- Retains the 1 MiB download buffer.
- Keeps the existing `bestaudio/best` source selector, metadata tagging and artwork processing.
- Keeps WebM/Opus container conversion as FFmpeg stream copy (`-c:a copy`), not audio re-encoding. The original downloaded audio stream is preserved.

Concurrency can improve segmented downloads, while HTTP chunking is an experimental yt-dlp option that may help when a server throttles large transfers; actual speed still depends on the source, format, server and connection.

## Safe installation

The installer backs up app.py, templates/index.html, the new CSS asset and the installed-version marker. It patches only the existing yt-dlp options dictionary and adds a separately versioned Home stylesheet. It restarts once, verifies the live Home page, served stylesheet, downloader settings and service health, and checks that the consolidated player/Home JavaScript and service worker remain byte-for-byte unchanged. If validation fails, it restores the backed-up files and restarts the previous app.

Automated tests cover the actual Home mood/station selectors, reduced-motion fallback, existing layout/renderer preservation, best-audio selection, 12-way fragment concurrency, retained HTTP chunk/buffer settings, metadata pipeline, idempotent application, Python syntax and untouched existing static assets. Physical-device animation and real-world download speed still need confirmation after installation.
