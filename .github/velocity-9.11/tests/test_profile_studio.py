#!/usr/bin/env python3
from pathlib import Path
import re

ROOT=Path(__file__).resolve().parents[1]
js=(ROOT/"payload/mv111-profile-studio.js").read_text(encoding="utf-8")
css=(ROOT/"payload/mv111-profile-studio.css").read_text(encoding="utf-8")
installer=(ROOT/"install-update.sh").read_text(encoding="utf-8")
version=(ROOT/"MUSIC_VAULT_RELEASE_VERSION.txt").read_text(encoding="utf-8").strip()

assert version=="9.11.0"
assert "/api/family" in js
assert "/api/auth" not in js and "password" not in js.lower()
assert "preventDefault" not in js and "stopPropagation" not in js
assert "addEventListener('click'" in js
assert "mv111-profile-grid" in js and "mv111-add-person" in js
assert "mv111-is-current" in js and "mv111-edit-action" in js
assert "Choose your profile" in js and "Your listening identities" in js
assert "profileveil" in js and "profilemodal" in js
assert "@media(max-width:720px)" in css
assert "@media(max-width:360px)" in css
assert "prefers-reduced-motion" in css
assert ":focus-visible" in css
assert "backdrop-filter" in css
assert "mv98" not in js and "mv98" not in css
assert "musicvault.db" in installer and "src.backup(dst)" in installer
assert "/api/family" in installer and "/api/status" in installer
assert "DROP TABLE" not in installer.upper()
assert "DELETE FROM" not in installer.upper()
assert "app.py" not in installer.split("mkdir -p",1)[-1].split("TMP=",1)[0]
assert "ROLLBACK_ACTIVE=1" in installer and "ROLLBACK_ACTIVE=0" in installer
assert "mv101-profile-chooser" in installer
assert "9.11.0" in installer
print("PASS: Music Vault 9.11 profile UI scope, password-free flow, responsive/accessibility, database immutability, and rollback checks.")
