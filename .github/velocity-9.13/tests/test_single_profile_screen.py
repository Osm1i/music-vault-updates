#!/usr/bin/env python3
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
js=(ROOT/"payload/mv113-profile-studio.js").read_text(encoding="utf-8")
css=(ROOT/"payload/mv113-profile-studio.css").read_text(encoding="utf-8")
installer=(ROOT/"install-update.sh").read_text(encoding="utf-8")
version=(ROOT/"MUSIC_VAULT_RELEASE_VERSION.txt").read_text(encoding="utf-8").strip()
assert version=="9.13.0"
assert "nativeVeil()" in js and "document.querySelectorAll('.profileveil')" in js
assert "body.classList.add(BODY_CLASS)" in js and "visibility:hidden" in css
assert "selectableTarget(source,scope)" in js and "action.click()" in js
assert "window.location.reload" not in js
assert "fetch('/api/profile/active'" not in js and 'fetch("/api/profile/active"' not in js
assert "/api/family" in js and "/api/auth" not in js and "password" not in js.lower()
assert "openLegacyAction(edit)" in js and "openLegacyAction(action)" in js
assert "mv112-profile-studio" in installer
assert "mv113-profile-studio.js" in installer and "mv113-profile-studio.css" in installer
assert "musicvault.db" in installer and "src.backup(dst)" in installer
assert "DROP TABLE" not in installer.upper() and "DELETE FROM" not in installer.upper()
assert "app.py" not in installer
assert "/api/family" in installer and "/api/status" in installer
assert "9.13.0" in installer and "ROLLBACK_ACTIVE=1" in installer
assert "#mv113-profile-studio" in css and ".profileveil" in css
assert "@media(max-width:620px)" in css and "@media(max-width:360px)" in css
print("PASS: v9.13 hides the original chooser, uses native profile click handlers, avoids forced reload, leaves backend/DB untouched, and has rollback.")
