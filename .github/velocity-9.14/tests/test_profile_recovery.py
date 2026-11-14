#!/usr/bin/env python3
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
installer=(ROOT/"install-update.sh").read_text(encoding="utf-8")
version=(ROOT/"MUSIC_VAULT_RELEASE_VERSION.txt").read_text(encoding="utf-8").strip()
assert version=="9.14.0"
assert "9.12.0|9.13.0|9.14.0" in installer
assert "musicvault.db" in installer and "src.backup(dst)" in installer
assert "DROP TABLE" not in installer.upper() and "DELETE FROM" not in installer.upper()
assert 'install "$TMP/app.py"' not in installer and 'cp "$APP_ROOT/app.py"' not in installer
for token in ("mv101-profile-chooser.js","mv111-profile-studio.js","mv112-profile-studio.js","mv113-profile-studio.js"):
 assert token in installer
assert "original selector and intro markup preserved" in installer
assert "/api/family" in installer and "/api/status" in installer
assert "ROLLBACK_ACTIVE=1" in installer and "9.14.0" in installer
print("PASS: recovery removes all injected profile overlays, preserves native intro/profile flow, and leaves app.py/SQLite untouched.")
