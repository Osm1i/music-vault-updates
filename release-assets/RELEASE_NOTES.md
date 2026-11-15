# Music Vault v9.25.0 — Recently Added Top Picks layout

Restyles the Home Recently Added section to match the cleaner Top Picks for You presentation from the supplied screenshot.

- Replaces the large two-column album tiles with one horizontally scrollable row of compact, rounded album cards.
- Uses square inset artwork, subtle gold borders/backgrounds, two-line album titles, and a single-line artist label.
- Removes the oversized play overlay from the card artwork so the row matches the reference's cleaner presentation.
- Preserves the existing Recently Added heading, collection count, newest-first ordering, album records, and album-open click handlers.
- Preserves the View All action and all existing Home, New, Radio, Library, Search, and More navigation.
- Keeps the existing 9.24.1 Home refresh/error recovery and YouTube downloader settings unchanged.

The installer changes only the Home template's versioned stylesheet reference and adds one CSS file. It backs up the template, new stylesheet and installed-version marker, restarts once to refresh Flask/Jinja, checks the live page and served stylesheet, and automatically restores the previous files if a validation fails.

Automated tests verify the card container, existing album data/click hooks, Home navigation, 9.24.1 asset preservation, horizontal scrolling and compact card styling, plus idempotent patching. Music files, database, app backend, playback bundle, service worker, profiles, playlists, favorites, queue, EQ and downloader settings remain untouched.
