# Music Vault Vanguard 9.1.0 — Velocity Edition

A performance-focused full app release on top of the Vanguard 9.0 redesign.

## Faster first view and library browsing
- Native lazy loading for artwork and images below the first screen, so long albums and library pages do not compete with visible content during startup.
- Asynchronous image decoding to reduce image work on the main rendering path.
- Browser-native fetch priority keeps visible content ahead of below-the-fold artwork.
- One bounded MutationObserver handles dynamically added library items without polling or repeatedly rescanning the entire page.
- CSS content-visibility defers rendering work for long album grids and song/track lists.
- A refreshed PWA cache version ensures the new performance layer is loaded after the update.

## App polish
- More consistent keyboard focus visibility.
- Honors reduced-motion preferences.
- Keeps the existing Vanguard 9.0 visual system and Home Screen identity.

## Compatibility and data safety
- Additive changes only: the existing index template is patched with two new asset references; it is not replaced.
- Preserves the existing player, audio engine, 10-band EQ, profile chooser, playlists, favorites, family data, downloader, import queue, backend routes, databases and music folders.
- No personal data or credentials are included in the release package.
- The existing updater still verifies the release SHA-256, makes a code-only backup, installs, restarts and performs its health check with rollback on failure.

## Install
Open Music Vault → Settings → Update Center → Check now → Install update.
