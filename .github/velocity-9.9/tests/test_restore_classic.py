#!/usr/bin/env python3
from pathlib import Path
import sys
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "payload"))
from restore_classic_auth import restore_classic_auth

APP_BLOCK = """# Music Vault 9.8 additive private-account integration.
from mv98_accounts import install_music_vault_accounts
install_music_vault_accounts(globals())

"""
CSS = '<link rel="stylesheet" href="/static/mv98-auth.css?v=9.8.0">'
JS = '<script src="/static/mv98-auth.js?v=9.8.0"></script>'
GATE = '<script>document.documentElement.classList.add("mv98-auth-pending")</script>\n'

app = "def existing_route():\n    return True\n\n" + APP_BLOCK + 'if __name__ == "__main__":\n    pass\n'
html = "<html><head>" + CSS + "\n" + GATE + "</head><body>" + JS + "</body></html>"
new_app, new_html = restore_classic_auth(app, html)
assert "install_music_vault_accounts" not in new_app
assert "mv98_accounts" not in new_app
assert "mv98-auth" not in new_html
assert "mv98-auth-pending" not in new_html
compile(new_app, "app.py", "exec")
again_app, again_html = restore_classic_auth(new_app, new_html)
assert again_app == new_app and again_html == new_html

installer = (ROOT / "install-update.sh").read_text(encoding="utf-8")
assert "musicvault.db" in installer and "src.backup(dst)" in installer
assert "/api/status" in installer
assert "mv98_accounts.py" in installer
assert "mv98-auth.js" in installer and "mv98-auth.css" in installer
assert "DROP TABLE" not in installer.upper()
assert 'rm -rf "$APP_ROOT"' not in installer
assert "9.9.0" in installer
print("PASS: classic profile restore package and data-safety checks.")
