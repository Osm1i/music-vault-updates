#!/usr/bin/env python3
"""Idempotently restyle Music Vault Home Recently Added to the Top Picks card rail."""
from pathlib import Path
import os
import re
import sys
import tempfile

VERSION = "9.25.0"
CSS_FILE = "mv925-recent-picks.css"
CSS_ID = "mv925-recent-picks-css"
CSS_TAG = f'<link id="{CSS_ID}" rel="stylesheet" href="/static/{CSS_FILE}?v={VERSION}">'


def patch_html(source: str) -> str:
    required = (
        'id="recentAlbums"',
        'data-page="home"',
        'data-page="new"',
        'data-page="radio"',
        'data-page="library"',
        'data-page="search"',
    )
    missing = [token for token in required if token not in source]
    if missing:
        raise RuntimeError("Expected Home album host/navigation markup is missing: " + ", ".join(missing))

    pattern = rf'<link\b(?=[^>]*\bid=["\']{re.escape(CSS_ID)}["\'])[^>]*>'
    source = re.sub(pattern, "", source, flags=re.I | re.S)
    if not re.search(r"</head\s*>", source, re.I):
        raise RuntimeError("Cannot find </head> insertion point in templates/index.html")
    source = re.sub(r"</head\s*>", lambda match: CSS_TAG + match.group(0), source, count=1, flags=re.I)
    if source.count(f'id="{CSS_ID}"') != 1:
        raise RuntimeError("Recently Added layout stylesheet did not register exactly once")
    return source


def atomic_write(path: Path, data: bytes):
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        st = path.stat()
        mode, uid, gid = st.st_mode & 0o777, st.st_uid, st.st_gid
    else:
        st = path.parent.stat()
        mode, uid, gid = 0o644, st.st_uid, st.st_gid
    fd, name = tempfile.mkstemp(prefix="." + path.name + ".mv925-", dir=path.parent)
    try:
        with os.fdopen(fd, "wb") as handle:
            handle.write(data)
            handle.flush()
            os.fsync(handle.fileno())
        os.chmod(name, mode)
        try:
            os.chown(name, uid, gid)
        except PermissionError:
            pass
        os.replace(name, path)
    finally:
        try:
            os.unlink(name)
        except FileNotFoundError:
            pass


def patch_app(root: Path):
    template = root / "templates/index.html"
    css_source = Path(__file__).with_name(CSS_FILE)
    if not template.is_file() or not css_source.is_file():
        raise RuntimeError("Required Home template or release stylesheet is missing")
    html = patch_html(template.read_text(encoding="utf-8"))
    css = css_source.read_bytes()
    atomic_write(root / "static" / CSS_FILE, css)
    atomic_write(template, html.encode("utf-8"))
    print("PASS: Recently Added now uses the compact Top Picks-style horizontal album cards.")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("Usage: patch_recent_added.py APP_ROOT")
    try:
        patch_app(Path(sys.argv[1]).resolve())
    except Exception as exc:
        raise SystemExit("PATCH ERROR: " + str(exc))
