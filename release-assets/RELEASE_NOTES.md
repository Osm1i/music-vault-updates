# Music Vault Vanguard 9.0 — The App Edition

A major end-to-end visual and interaction redesign that makes Music Vault feel like a polished installed music app across desktop, iPhone and tablet.

## The experience
- Unified dark-olive and champagne-gold design language with refined typography, app surfaces, buttons, cards and navigation.
- Rebuilt desktop frame with a deliberate sidebar, cleaner top bar, persistent listening dock and stronger visual hierarchy.
- Redesigned Listen Now home, editorial New and Radio pages, Favorites, Search and Library dashboards.
- More cohesive Import, Queue, USB & Folders, Family Library, Profile, Settings and Update Center screens.
- Redesigned album details and full-screen listening studio, with prominent controls and iPhone safe-area handling.
- App-wide Quick Actions launcher: click its button or press Ctrl/⌘ + K (or / outside text fields) to jump to major areas, Now Playing, Queue or profiles.
- Refreshed PWA metadata and app-shell cache while retaining the existing home-screen icon files.

## Compatibility and data safety
- The installer patches existing page markup additively; it does not replace the original template.
- Preserves player markup, routes, audio engine, 10-band EQ, profile chooser, personal profiles, playlists, favorites, family data, downloader, import queue and backend APIs.
- This is a presentation/PWA update. It does not replace app.py, databases, music folders, profile data or server configuration.
- The existing update agent creates a code-only rollback snapshot before installation and restores it if the installer or health check fails.

## Install
Open Music Vault → Settings → Update Center → Check now → Install update. The server downloads the private release, verifies its SHA-256 digest, makes its backup, installs the update and restarts the service.
