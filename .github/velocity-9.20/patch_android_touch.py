#!/usr/bin/env python3
"""Idempotent mobile viewport and Android touch patch; leaves app JS/SW untouched."""
from pathlib import Path
import os
import re
import sys
import tempfile

VERSION = '9.20.0'
CSS = 'mv920-android-touch.css'
VIEWPORT = '<meta id="mv920-viewport" name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">'
LINK = f'<link id="mv920-android-touch-css" rel="stylesheet" href="/static/{CSS}?v={VERSION}">'
SCRIPT = ('<script id="mv920-android-touch-detect">(function(){try{'
          'if(/Android/i.test(navigator.userAgent||""))document.documentElement.classList.add("mv920-android");'
          '}catch(_){}})();</script>')


def patch_html(source: str) -> str:
    # Replace all old viewport declarations with one predictable responsive viewport.
    source = re.sub(r'<meta\b(?=[^>]*\bname\s*=\s*["\']viewport["\'])[^>]*>', '', source, flags=re.I)
    # Remove prior Android patch hooks/links, without touching unrelated page assets.
    for version in ('920', '919', '918', '917', '916'):
        source = re.sub(r'<script\b[^>]*id=["\']mv' + version + r'-android-touch-detect["\'][^>]*>.*?</script\s*>', '', source, flags=re.I|re.S)
        source = re.sub(r'<link\b(?=[^>]*id=["\']mv' + version + r'-android-touch-css["\'])[^>]*>', '', source, flags=re.I)
        source = re.sub(r'<meta\b(?=[^>]*id=["\']mv' + version + r'-viewport["\'])[^>]*>', '', source, flags=re.I)
    block = VIEWPORT + SCRIPT + LINK
    if re.search(r'</head\s*>', source, re.I):
        return re.sub(r'</head\s*>', lambda m: block + m.group(0), source, count=1, flags=re.I)
    raise RuntimeError('Cannot find </head> insertion point in templates/index.html')


def atomic_write(path: Path, data: bytes):
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        st = path.stat(); mode = st.st_mode & 0o777; uid, gid = st.st_uid, st.st_gid
    else:
        st = path.parent.stat(); mode = 0o644; uid, gid = st.st_uid, st.st_gid
    fd, name = tempfile.mkstemp(prefix='.' + path.name + '.mv920-', dir=path.parent)
    try:
        with os.fdopen(fd, 'wb') as handle:
            handle.write(data); handle.flush(); os.fsync(handle.fileno())
        os.chmod(name, mode)
        try: os.chown(name, uid, gid)
        except PermissionError: pass
        os.replace(name, path)
    finally:
        try: os.unlink(name)
        except FileNotFoundError: pass


def patch_app(root: Path):
    template = root / 'templates/index.html'
    css_source = Path(__file__).with_name(CSS)
    if not template.is_file() or not css_source.is_file():
        raise RuntimeError('Required template or stylesheet package file missing')
    html = patch_html(template.read_text(encoding='utf-8'))
    css = css_source.read_bytes()
    atomic_write(root / 'static' / CSS, css)
    atomic_write(template, html.encode('utf-8'))
    print('PASS: responsive viewport, Android touch stylesheet and detector registered once.')


if __name__ == '__main__':
    if len(sys.argv) != 2: raise SystemExit('Usage: patch_android_touch.py APP_ROOT')
    try: patch_app(Path(sys.argv[1]).resolve())
    except Exception as exc: raise SystemExit('PATCH ERROR: ' + str(exc))
