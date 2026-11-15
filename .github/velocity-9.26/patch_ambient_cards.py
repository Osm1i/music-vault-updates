#!/usr/bin/env python3
"""Idempotently add ambient animations to Music Vault recommendation cards and tune yt-dlp."""
from pathlib import Path
import os
import re
import sys
import tempfile

VERSION = "9.26.0"
CSS_FILE = "mv926-ambient-cards.css"
CSS_ID = "mv926-ambient-cards-css"
CSS_TAG = f'<link id="{CSS_ID}" rel="stylesheet" href="/static/{CSS_FILE}?v={VERSION}">'


def patch_html(source: str) -> str:
    required = ('id="page-home"', 'id="mv-consolidated-js"')
    missing = [token for token in required if token not in source]
    if missing:
        raise RuntimeError("Expected Music Vault Home renderer markup is missing: " + ", ".join(missing))
    pattern = rf'''<link\b(?=[^>]*\bid=["\']{re.escape(CSS_ID)}["\'])[^>]*>'''
    source = re.sub(pattern, "", source, flags=re.I | re.S)
    if not re.search(r"</head\s*>", source, re.I):
        raise RuntimeError("Cannot find </head> insertion point in templates/index.html")
    source = re.sub(r"</head\s*>", lambda match: CSS_TAG + match.group(0), source, count=1, flags=re.I)
    if source.count(f'id="{CSS_ID}"') != 1:
        raise RuntimeError("Ambient animation stylesheet did not register exactly once")
    return source


def set_option(line: str, key: str, expression: str) -> str:
    pattern = rf'''(["\']{re.escape(key)}["\']\s*:\s*)([^,}}]+)'''
    matches = list(re.finditer(pattern, line))
    if len(matches) > 1:
        raise RuntimeError(f"Duplicate yt-dlp option: {key}")
    if matches:
        old = matches[0].group(2).strip()
        if old == expression:
            return line
        start, end = matches[0].span(2)
        return line[:start] + expression + line[end:]
    marker = "'format':'bestaudio/best',"
    if line.count(marker) != 1:
        raise RuntimeError("Cannot safely insert downloader option after the best-audio selector")
    return line.replace(marker, marker + f"'{key}':{expression},", 1)


def patch_download_options(source: str) -> str:
    lines = source.splitlines(keepends=True)
    indexes = [i for i, line in enumerate(lines) if re.search(r"\bopts\s*=\s*\{", line)]
    if len(indexes) != 1:
        raise RuntimeError(f"Expected one yt-dlp options dictionary, found {len(indexes)}; refusing to guess")
    idx = indexes[0]
    line = lines[idx]
    if "'format':'bestaudio/best'" not in line:
        raise RuntimeError("The existing best-audio format selector was not found; refusing to alter sound-quality selection")
    line = set_option(line, "concurrent_fragment_downloads", "12")
    line = set_option(line, "http_chunk_size", "10*1024*1024")
    line = set_option(line, "buffersize", "1024*1024")
    lines[idx] = line
    result = "".join(lines)
    if "'format':'bestaudio/best'" not in result:
        raise RuntimeError("Best-audio selector changed unexpectedly")
    return result


def atomic_write(path: Path, data: bytes):
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        st = path.stat()
        mode, uid, gid = st.st_mode & 0o777, st.st_uid, st.st_gid
    else:
        st = path.parent.stat()
        mode, uid, gid = 0o644, st.st_uid, st.st_gid
    fd, name = tempfile.mkstemp(prefix="." + path.name + ".mv926-", dir=path.parent)
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
    css_source = Path(__file__).with_name(CSS_FILE)
    for required in (template, app_py, css_source):
        if not required.is_file():
            raise RuntimeError(f"Required package or application file missing: {required.name}")
    html = patch_html(template.read_text(encoding="utf-8"))
    app_source = patch_download_options(app_py.read_text(encoding="utf-8"))
    css = css_source.read_bytes()
    atomic_write(app_py, app_source.encode("utf-8"))
    atomic_write(root / "static" / CSS_FILE, css)
    atomic_write(template, html.encode("utf-8"))
    print("PASS: Home mood/station cards animated; YouTube downloader set to 12 concurrent fragments with best-audio source retained.")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("Usage: patch_ambient_cards.py APP_ROOT")
    try:
        patch_app(Path(sys.argv[1]).resolve())
    except Exception as exc:
        raise SystemExit("PATCH ERROR: " + str(exc))
