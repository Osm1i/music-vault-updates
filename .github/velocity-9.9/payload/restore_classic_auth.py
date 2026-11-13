#!/usr/bin/env python3
"""Remove only the additive Music Vault 9.8 private-account startup hooks."""
from __future__ import annotations
import re
import sys
from pathlib import Path

APP_HOOK = re.compile(
    r"\n# Music Vault 9\.8 additive private-account integration\.\r?\n"
    r"from mv98_accounts import install_music_vault_accounts\r?\n"
    r"install_music_vault_accounts\(globals\(\)\)\r?\n\r?\n"
)
AUTH_CSS = '<link rel="stylesheet" href="/static/mv98-auth.css?v=9.8.0">'
AUTH_JS = '<script src="/static/mv98-auth.js?v=9.8.0"></script>'
AUTH_GATE = re.compile(
    r'<script>\s*document\.documentElement\.classList\.add\(["\']mv98-auth-pending["\']\)\s*</script>\s*'
)

def restore_classic_auth(app_source: str, html: str) -> tuple[str, str]:
    hooks = list(APP_HOOK.finditer(app_source))
    if len(hooks) > 1:
        raise RuntimeError("Found multiple 9.8 account startup hooks; refusing an ambiguous edit.")
    if hooks:
        app_source = APP_HOOK.sub("\n", app_source, count=1)
    elif "install_music_vault_accounts" in app_source or "mv98_accounts" in app_source:
        raise RuntimeError("Found an unrecognized account hook; refusing to leave partial authentication active.")

    html = html.replace(AUTH_CSS, "")
    html = html.replace(AUTH_JS, "")
    html, _ = AUTH_GATE.subn("", html)
    if "mv98-auth" in html or "mv98-auth-pending" in html:
        raise RuntimeError("Unrecognized 9.8 authentication markup remains; refusing a partial restore.")
    if "install_music_vault_accounts" in app_source or "mv98_accounts" in app_source:
        raise RuntimeError("Account module reference remains in app.py.")
    compile(app_source, "app.py", "exec")
    return app_source, html

def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("Usage: restore_classic_auth.py APP_PY INDEX_HTML")
    app_path = Path(sys.argv[1])
    html_path = Path(sys.argv[2])
    app_source, html = restore_classic_auth(
        app_path.read_text(encoding="utf-8"),
        html_path.read_text(encoding="utf-8"),
    )
    app_path.write_text(app_source, encoding="utf-8")
    html_path.write_text(html, encoding="utf-8")
    print("PASS: 9.8 account startup hook, sign-in assets and pending gate removed.")

if __name__ == "__main__":
    main()
