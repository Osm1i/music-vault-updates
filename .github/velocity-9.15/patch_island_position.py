#!/usr/bin/env python3
"""Apply the Music Vault 9.15.0 bottom-island position-only patch."""
from pathlib import Path
import os
import re
import sys
import tempfile

VERSION = "9.15.0"

def replace_count(pattern: str, replacement: str, source: str, expected: int, label: str) -> str:
    updated, count = re.subn(pattern, replacement, source)
    if count != expected:
        raise RuntimeError(f"{label}: expected {expected} position rules, found {count}; refusing partial update")
    return updated

def transform_css(source: str) -> str:
    return replace_count(
        r"(bottom:calc\(env\(safe-area-inset-bottom,0px\) \+ )\d+px(\)!important;)",
        r"\g<1>0px\g<2>", source, 4, "CSS"
    )

def transform_js(source: str) -> str:
    return replace_count(
        r"(dock\.style\.setProperty\('bottom','calc\(env\(safe-area-inset-bottom, 0px\) \+ )\d+px(\)','important'\))",
        r"\g<1>0px\g<2>", source, 2, "JavaScript"
    )

def transform_index(source: str) -> str:
    source = replace_count(
        r'(/static/mv-consolidated\.css\?v=)[^"\']+',
        r'\g<1>' + VERSION, source, 1, "index CSS cache reference"
    )
    return replace_count(
        r'(/static/mv-consolidated\.js\?v=)[^"\']+',
        r'\g<1>' + VERSION, source, 1, "index JavaScript cache reference"
    )

def transform_sw(source: str) -> str:
    source = replace_count(
        r"(?m)^const CACHE='[^']+';",
        "const CACHE='music-vault-shell-v9-15-0-island-position-v1';",
        source, 1, "service-worker cache key"
    )
    source = replace_count(
        r"'/static/mv-consolidated\.css\?v=[^']+'",
        "'/static/mv-consolidated.css?v=9.15.0'",
        source, 1, "service-worker CSS cache reference"
    )
    return replace_count(
        r"'/static/mv-consolidated\.js\?v=[^']+'",
        "'/static/mv-consolidated.js?v=9.15.0'",
        source, 1, "service-worker JavaScript cache reference"
    )

def atomic_write(path: Path, content: str) -> None:
    old = path.stat()
    fd, temp_name = tempfile.mkstemp(prefix=f".{path.name}.mv915-", dir=str(path.parent))
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="") as handle:
            handle.write(content)
            handle.flush()
            os.fsync(handle.fileno())
        os.chmod(temp_name, old.st_mode & 0o777)
        try:
            os.chown(temp_name, old.st_uid, old.st_gid)
        except PermissionError:
            pass
        os.replace(temp_name, path)
    finally:
        try:
            os.unlink(temp_name)
        except FileNotFoundError:
            pass

def patch_app(app_root: Path) -> None:
    targets = {
        "css": app_root / "static/mv-consolidated.css",
        "js": app_root / "static/mv-consolidated.js",
        "index": app_root / "templates/index.html",
        "sw": app_root / "static/sw.js",
    }
    for label, path in targets.items():
        if not path.is_file() or path.stat().st_size == 0:
            raise RuntimeError(f"Required Music Vault {label} file is missing: {path}")
    transformed = {
        "css": transform_css(targets["css"].read_text(encoding="utf-8")),
        "js": transform_js(targets["js"].read_text(encoding="utf-8")),
        "index": transform_index(targets["index"].read_text(encoding="utf-8")),
        "sw": transform_sw(targets["sw"].read_text(encoding="utf-8")),
    }
    for label, path in targets.items():
        atomic_write(path, transformed[label])
    atomic_write(app_root / "data/installed_version.txt", VERSION + "\n")
    print("PASS: all dock position controllers now use safe-area + 0px (8px lower).")
    print("PASS: asset URLs and service-worker cache key are now 9.15.0.")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("Usage: patch_island_position.py /opt/music-vault")
    try:
        patch_app(Path(sys.argv[1]).resolve())
    except Exception as exc:
        raise SystemExit(f"PATCH ERROR: {exc}")
