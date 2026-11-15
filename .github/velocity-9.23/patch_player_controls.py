#!/usr/bin/env python3
"""Idempotent additive player favorite/clear controls patch for Music Vault 9.23.0."""
from pathlib import Path
import os
import re
import sys
import tempfile

VERSION = "9.23.0"
JS_FILE = "mv923-player-controls.js"
CSS_FILE = "mv923-player-controls.css"
CSS_LINK = f'<link id="mv923-player-controls-css" rel="stylesheet" href="/static/{CSS_FILE}?v={VERSION}">'
JS_TAG = f'<script id="mv923-player-controls-js" src="/static/{JS_FILE}?v={VERSION}"></script>'

MINI_LIKE = '<button class="mini-like" id="miniLike" onclick="event.stopPropagation();toggleCurrentFavorite()" title="Favorite">♡</button>'
MINI_CLEAR = '<button class="mini-clear" id="miniClear" type="button" onclick="event.stopPropagation();window.mv923ClearPlayer?.()" aria-label="Stop and clear song" title="Stop and clear song">×</button>'
CLEAR_FN = r'''window.mv923ClearPlayer=()=>{
 queue.length=0;currentIndex=-1;duration=0;lyricsRows=[];
 if(lyricsTimer){clearInterval(lyricsTimer);lyricsTimer=null;}
 A.pause();A.removeAttribute('src');A.load();
 try{A.currentTime=0;}catch(e){}
 renderQueue();paint();store();
 if(navigator.mediaSession){try{navigator.mediaSession.metadata=null;navigator.mediaSession.playbackState='none';}catch(e){}}
 window.closeNowPlaying?.();
 return true;
};
'''


def replace_once(source: str, old: str, new: str, label: str) -> str:
    # Check the complete replacement first: several anchors are prefixes of their patched form.
    if new in source:
        return source
    count = source.count(old)
    if count == 0:
        raise RuntimeError(f"Expected {label} anchor was not found; refusing to guess at this app version")
    if count != 1:
        raise RuntimeError(f"Expected exactly one {label} anchor, found {count}")
    return source.replace(old, new, 1)


def remove_tag_by_id(source: str, tag: str, element_id: str) -> str:
    pattern = rf'<{tag}\b(?=[^>]*\bid=["\']{re.escape(element_id)}["\'])[^>]*>(?:\s*</{tag}\s*>)?'
    return re.sub(pattern, '', source, flags=re.I | re.S)


def patch_player_script(source: str) -> str:
    # Apply only within the known standalone-player inline script.
    matches = list(re.finditer(r'<script\b[^>]*id=["\']music-vault-standalone-player["\'][^>]*>(.*?)</script\s*>', source, re.I | re.S))
    if len(matches) != 1:
        raise RuntimeError(f"Expected one standalone player script, found {len(matches)}")
    match = matches[0]
    player = match.group(1)

    player = replace_once(
        player,
        "function paint(){let t=current();if(!t){",
        "function paint(){let t=current();if(!t){$('miniPlayer').hidden=true;",
        "empty-player visibility hook",
    )
    player = replace_once(
        player,
        "$('miniTitle').textContent=t.title;",
        "$('miniPlayer').hidden=false;$('miniTitle').textContent=t.title;",
        "active-player visibility hook",
    )
    player = replace_once(
        player,
        "$('miniLike').textContent='♡';$('nowFavorite').textContent='♡';",
        "$('miniLike').textContent='♡';$('nowFavorite').textContent='♡';[$('miniLike'),$('nowFavorite')].forEach(b=>{b?.classList.remove('is-favorite');b?.setAttribute('aria-pressed','false')});window.mv923SyncFavoriteState?.(t.id);",
        "current-track favorite sync hook",
    )
    player = replace_once(
        player,
        "window.playTracks=(items,index=0,append=false)=>",
        CLEAR_FN + "window.playTracks=(items,index=0,append=false)=>",
        "clear-player API insertion point",
    )
    return source[:match.start(1)] + player + source[match.end(1):]


def patch_html(source: str) -> str:
    # Replace our own versioned tags on re-run, but leave all other app assets intact.
    source = remove_tag_by_id(source, "link", "mv923-player-controls-css")
    source = remove_tag_by_id(source, "script", "mv923-player-controls-js")

    if MINI_CLEAR not in source:
        source = replace_once(source, MINI_LIKE, MINI_LIKE + MINI_CLEAR, "mini-player favorite button")

    source = patch_player_script(source)

    if not re.search(r'</head\s*>', source, re.I):
        raise RuntimeError("Cannot find </head> insertion point in templates/index.html")
    if not re.search(r'</body\s*>', source, re.I):
        raise RuntimeError("Cannot find </body> insertion point in templates/index.html")

    source = re.sub(r'</head\s*>', lambda m: CSS_LINK + m.group(0), source, count=1, flags=re.I)
    source = re.sub(r'</body\s*>', lambda m: JS_TAG + m.group(0), source, count=1, flags=re.I)

    if source.count('id="miniClear"') != 1:
        raise RuntimeError("Mini-player clear button did not register exactly once")
    if source.count('id="mv923-player-controls-css"') != 1:
        raise RuntimeError("Player-controls stylesheet did not register exactly once")
    if source.count('id="mv923-player-controls-js"') != 1:
        raise RuntimeError("Player-controls script did not register exactly once")
    if source.count("window.mv923ClearPlayer=()=>") != 1:
        raise RuntimeError("Clear-player API did not register exactly once")
    return source


def atomic_write(path: Path, data: bytes):
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        st = path.stat()
        mode = st.st_mode & 0o777
        uid, gid = st.st_uid, st.st_gid
    else:
        st = path.parent.stat()
        mode = 0o644
        uid, gid = st.st_uid, st.st_gid
    fd, name = tempfile.mkstemp(prefix="." + path.name + ".mv923-", dir=path.parent)
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
    js_source = Path(__file__).with_name(JS_FILE)
    css_source = Path(__file__).with_name(CSS_FILE)
    if not template.is_file() or not js_source.is_file() or not css_source.is_file():
        raise RuntimeError("Required template, script, or stylesheet package file missing")
    html = patch_html(template.read_text(encoding="utf-8"))
    js = js_source.read_bytes()
    css = css_source.read_bytes()
    atomic_write(root / "static" / JS_FILE, js)
    atomic_write(root / "static" / CSS_FILE, css)
    atomic_write(template, html.encode("utf-8"))
    print("PASS: profile-aware red/outline favorite state and stop/clear mini-player action registered once.")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("Usage: patch_player_controls.py APP_ROOT")
    try:
        patch_app(Path(sys.argv[1]).resolve())
    except Exception as exc:
        raise SystemExit("PATCH ERROR: " + str(exc))
