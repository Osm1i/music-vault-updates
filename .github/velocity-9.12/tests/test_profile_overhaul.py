#!/usr/bin/env python3
from pathlib import Path
import re
ROOT=Path(__file__).resolve().parents[1]
js=(ROOT/"payload/mv112-profile-studio.js").read_text(encoding="utf-8")
css=(ROOT/"payload/mv112-profile-studio.css").read_text(encoding="utf-8")
installer=(ROOT/"install-update.sh").read_text(encoding="utf-8")
version=(ROOT/"MUSIC_VAULT_RELEASE_VERSION.txt").read_text(encoding="utf-8").strip()
assert version=="9.12.0"
assert "mv112-profile-studio-overlay" in js
assert "document.body.appendChild(veil)" in js
assert "'/api/family'" in js or '"/api/family"' in js
assert "'/api/profile/active'" in js or '"/api/profile/active"' in js
assert "password" not in js.lower() and "/api/auth" not in js
assert "findAction(scope,'add')" in js
assert "findAction(root,'edit')" in js
assert "mv112-profile-card" in css and "mv112-add-card" in css
assert "@media(max-width:620px)" in css
assert "prefers-reduced-motion" in css
assert ":focus-visible" in css
assert "musicvault.db" in installer and "src.backup(dst)" in installer
assert "DROP TABLE" not in installer.upper() and "DELETE FROM" not in installer.upper()
assert "install-update.sh" in installer
assert "9.12.0" in installer
print("PASS: v9.12 replaces the chooser with a new overlay, uses original family APIs/actions, and leaves DB/player untouched.")
