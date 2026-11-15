# Music Vault v9.22.0 — Android touch and scroll recovery

This update targets the Android-only freeze that can appear after leaving the “Who’s listening?” profile picker and entering Listen Now.

- Restores native one-finger vertical/horizontal panning and pinch zoom across Android page content.
- Re-enables document scrolling and detects dynamically rendered content panels whose overflow is locked despite having more content than their visible area.
- Keeps buttons, links, and form controls touchable, with 44px minimum targets and the existing bottom-navigation safe-area spacing.
- Replaces the prior Android viewport/touch hook with one versioned, idempotent recovery hook.
- Does not change iOS behavior, playback JavaScript, the service worker, music files, database records, profiles, playlists, favorites, history, queue, EQ, or USB settings.
- Backs up the template, new touch stylesheet, and installed-version marker before changes. Restarts once to refresh Flask/Jinja, verifies the live HTML/CSS and service health, and rolls back the changed files if validation fails.

Automated tests cover viewport normalization, legacy-hook replacement, Android scroll/touch CSS, inline JavaScript syntax, idempotent application, and untouched playback/service-worker assets. Physical-device gesture behavior still requires confirmation on the affected Android phone.