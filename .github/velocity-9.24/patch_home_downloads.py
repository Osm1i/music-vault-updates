#!/usr/bin/env python3
"""Idempotent additive Music Vault 9.24.0 home-feed and download-speed patch."""
from pathlib import Path
import os
import re
import sys
import tempfile

VERSION = "9.24.0"
JS_FILE = "mv924-home-repair.js"
CSS_FILE = "mv924-home-repair.css"
JS_ID = "mv924-home-repair-js"
CSS_ID = "mv924-home-repair-css"
JS_TAG = f'<script id="{JS_ID}" src="/static/{JS_FILE}?v={VERSION}" defer></script>'
CSS_TAG = f'<link id="{CSS_ID}" rel="stylesheet" href="/static/{CSS_FILE}?v={VERSION}">'


def add_tag(source: str, tag_id: str, tag_name: str, tag: str, close_tag: str) -> str:
    pattern = rf'<{tag_name}\b(?=[^>]*\bid=["\']{re.escape(tag_id)}["\'])[^>]*>(?:\s*</{tag_name}\s*>)?'
    source = re.sub(pattern, '', source, flags=re.I | re.S)
    if not re.search(re.escape(close_tag), source, flags=re.I):
        raise RuntimeError(f"Cannot find {close_tag} insertion point")
    return re.sub(re.escape(close_tag), lambda m: tag + m.group(0), source, count=1, flags=re.I)


def patch_html(source: str) -> str:
    if 'id="recentAlbums"' not in source:
        raise RuntimeError("Home Recently Added container #recentAlbums is missing")
    if (
        'class="mobile-nav"' not in source
        or 'data-page="new"' not in source
        or 'data-page="radio"' not in source
        or 'data-page="search"' not in source
        or 'data-page="library"' not in source
    ):
        raise RuntimeError("Expected primary navigation structure is missing; refusing to change it")
    source = add_tag(source, CSS_ID, "link", CSS_TAG, "</head>")
    source = add_tag(source, JS_ID, "script", JS_TAG, "</body>")
    if source.count(f'id="{CSS_ID}"') != 1 or source.count(f'id="{JS_ID}"') != 1:
        raise RuntimeError("Home repair assets did not register exactly once")
    return source


def patch_download_options(source: str) -> str:
    marker = "opts={'format':'bestaudio/best',"
    tuned = "'concurrent_fragment_downloads':8,'http_chunk_size':10*1024*1024,'buffersize':1024*1024,"
    if tuned in source:
        return source
    count = source.count(marker)
    if count != 1:
        raise RuntimeError(f"Expected exactly one yt-dlp URL options block, found {count}; refusing to guess")
    return source.replace(marker, marker + tuned, 1)


def atomic_write(path: Path, data: bytes):
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        st = path.stat()
        mode, uid, gid = st.st_mode & 0o777, st.st_uid, st.st_gid
    else:
        st = path.parent.stat()
        mode, uid, gid = 0o644, st.st_uid, st.st_gid
    fd, name = tempfile.mkstemp(prefix="." + path.name + ".mv924-", dir=path.parent)
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
    app_py = root / "app.py"
    js_path = Path(__file__).with_name(JS_FILE)
    css_path = Path(__file__).with_name(CSS_FILE)
    for required in (template, app_py, js_path, css_path):
        if not required.is_file():
            raise RuntimeError(f"Required package or application file missing: {required.name}")
    html = patch_html(template.read_text(encoding="utf-8"))
    app_source = patch_download_options(app_py.read_text(encoding="utf-8"))
    js = js_path.read_bytes()
    css = css_path.read_bytes()
    atomic_write(app_py, app_source.encode("utf-8"))
    atomic_write(root / "static" / JS_FILE, js)
    atomic_write(root / "static" / CSS_FILE, css)
    atomic_write(template, html.encode("utf-8"))
    print("PASS: Recently Added grid, home error recovery, tab routing, and faster yt-dlp options registered.")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("Usage: patch_home_downloads.py APP_ROOT")
    try:
        patch_app(Path(sys.argv[1]).resolve())
    except Exception as exc:
        raise SystemExit("PATCH ERROR: " + str(exc))
