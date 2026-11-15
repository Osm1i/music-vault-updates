# Music Vault v9.20.0 — Android viewport and touch recovery

This release fixes the Android app's desktop-width/zoomed viewport behavior and restores standard one-finger interaction across the interface.

Changes:
- Ensures there is exactly one mobile viewport declaration using the device width, so responsive layouts and touch-sized controls activate on Android.
- Removes restrictive legacy viewport settings such as a forced desktop width or disabled user zoom.
- Restores native horizontal/vertical panning and pinch zoom on Android, while keeping buttons, links and form controls directly touchable.
- Retains the bottom navigation safe-area adjustment and 44px minimum control targets.
- Replaces the prior Android touch hook/style without changing Music Vault playback JavaScript or the service worker.
- Backs up the exact template, touch stylesheet and installed-version marker before applying changes.
- Restarts Music Vault once to refresh Flask/Jinja's cached template, then verifies the served HTML, stylesheet bytes and service health.
- Automatically restores the backed-up files and restarts the previous app if a live check fails.

Validation: package regression tests, Python compilation, shell syntax, idempotency checks, viewport normalization tests, untouched-player/service-worker checks, SHA-256 verification and ZIP integrity verification run before publication. Physical-device touch behavior still requires confirmation on the affected Android screen.
