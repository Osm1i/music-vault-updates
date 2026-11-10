#!/usr/bin/env python3
"""Prepare the 9.1.0 additive Velocity Edition inside the archived 9.0 package."""
from __future__ import annotations
import hashlib
import re
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
VERSION = "9.1.0"

def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: prepare_release.py STAGE_DIR VERSION")
    stage = Path(sys.argv[1]).resolve()
    version = sys.argv[2].strip()
    if version != VERSION:
        raise SystemExit(f"This patch is only for {VERSION}, not {version}")
    static = stage / "static"
    static.mkdir(parents=True, exist_ok=True)
    for filename in ("mv91-velocity.css", "mv91-velocity.js"):
        source = ROOT / filename
        if not source.is_file():
            raise SystemExit(f"Missing release source: {source}")
        shutil.copy2(source, static / filename)

    sw = static / "sw.js"
    if not sw.is_file():
        raise SystemExit("The package is missing static/sw.js")
    sw_text = sw.read_text(encoding="utf-8")
    updated, count = re.subn(
        r"const CACHE=(['\"])music-vault-shell-v\d+-\d+(?:-\d+)?\1",
        "const CACHE='music-vault-shell-v9-1-0'",
        sw_text, count=1,
    )
    if count != 1:
        raise SystemExit("Could not safely identify the Music Vault PWA cache version.")
    sw.write_text(updated, encoding="utf-8")

    installer = stage / "install-update.sh"
    if not installer.is_file():
        raise SystemExit("The package is missing install-update.sh")
    source = installer.read_text(encoding="utf-8")
    marker = "# MV91_VELOCITY_BOOTSTRAP"
    if marker not in source:
        bootstrap = r'''
# MV91_VELOCITY_BOOTSTRAP
set -e
MV91_APP="/opt/music-vault"
MV91_PACKAGE_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
install -D -m 0644 "$MV91_PACKAGE_DIR/static/mv91-velocity.css" "$MV91_APP/static/mv91-velocity.css"
install -D -m 0644 "$MV91_PACKAGE_DIR/static/mv91-velocity.js" "$MV91_APP/static/mv91-velocity.js"
python3 - "$MV91_APP/templates/index.html" <<'MV91_HTML_PATCH'
from pathlib import Path
import sys
page = Path(sys.argv[1])
html = page.read_text(encoding="utf-8")
if "mv91-velocity.css" not in html:
    if "</head>" not in html.lower():
        raise SystemExit("Cannot safely add Velocity stylesheet: </head> is missing.")
    pos = html.lower().find("</head>")
    html = html[:pos] + '<link rel="stylesheet" href="/static/mv91-velocity.css?v=9.1.0">\n' + html[pos:]
if "mv91-velocity.js" not in html:
    if "</body>" not in html.lower():
        raise SystemExit("Cannot safely add Velocity script: </body> is missing.")
    pos = html.lower().find("</body>")
    html = html[:pos] + '<script defer src="/static/mv91-velocity.js?v=9.1.0"></script>\n' + html[pos:]
page.write_text(html, encoding="utf-8")
MV91_HTML_PATCH
# END MV91_VELOCITY_BOOTSTRAP
'''
        lines = source.splitlines(keepends=True)
        if not lines or not lines[0].startswith("#!"):
            raise SystemExit("Installer has no recognized shell shebang.")
        source = lines[0] + bootstrap + "\n" + "".join(lines[1:])
        installer.write_text(source, encoding="utf-8")

    version_file = stage / "MUSIC_VAULT_RELEASE_VERSION.txt"
    version_file.write_text(VERSION + "\n", encoding="utf-8")
    checksum = stage / "SHA256SUMS_9_0.txt"
    if not checksum.exists():
        raise SystemExit("The package is missing SHA256SUMS_9_0.txt")
    rows = []
    for path in sorted(p for p in stage.rglob("*") if p.is_file() and p != checksum):
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        rows.append(f"{digest}  {path.relative_to(stage).as_posix()}\n")
    checksum.write_text("".join(rows), encoding="utf-8")

    js_text = (static / "mv91-velocity.js").read_text(encoding="utf-8")
    css_text = (static / "mv91-velocity.css").read_text(encoding="utf-8")
    if "img.loading = critical ? 'eager' : 'lazy'" not in js_text:
        raise SystemExit("Lazy image loading smoke check failed.")
    if "MutationObserver" not in js_text or "content-visibility: auto" not in css_text:
        raise SystemExit("Velocity rendering smoke check failed.")
    if marker not in installer.read_text(encoding="utf-8"):
        raise SystemExit("Installer bootstrap injection failed.")
    print("PASS: lazy image loading and async decoding assets included")
    print("PASS: long-list rendering containment included")
    print("PASS: existing index receives additive asset references")
    print("PASS: PWA cache version advanced to 9.1.0")
    print(f"PASS: regenerated SHA-256 manifest for {len(rows)} package files")

if __name__ == "__main__":
    main()
