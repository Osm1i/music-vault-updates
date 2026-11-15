from pathlib import Path
import re
import subprocess
import sys
import tempfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from patch_android_touch import patch_html, patch_app, CSS, SCRIPT

source = (
    '<html><head>'
    '<meta name="viewport" content="width=980, initial-scale=0.5, user-scalable=no">'
    '<link id="mv920-android-touch-css" href="/static/mv920-android-touch.css">'
    '<script id="mv920-android-touch-detect">old()</script>'
    '<script id="keep-existing-player">player()</script>'
    '<title>Music Vault</title></head><body><main class="mobile-nav"></main></body></html>'
)
patched = patch_html(source)
assert patched.count('name="viewport"') == 1
assert 'width=device-width, initial-scale=1, viewport-fit=cover' in patched
assert 'width=980' not in patched and 'user-scalable=no' not in patched
assert patched.count('mv922-android-touch-css') == 1
assert patched.count('mv922-android-touch-recovery') == 1
assert 'mv920-android-touch-css' not in patched
assert 'mv920-android-touch-detect' not in patched
assert 'keep-existing-player' in patched
assert patch_html(patched) == patched

css = (Path(__file__).resolve().parents[1] / CSS).read_text(encoding="utf-8")
for token in (
    "html.mv922-android body *",
    "touch-action: pan-x pan-y pinch-zoom !important",
    "html.mv922-android",
    "overflow-y: auto !important",
    "-webkit-overflow-scrolling: touch !important",
    "overscroll-behavior-y: auto !important",
    "pointer-events: auto !important",
    "touch-action: manipulation !important",
    "min-height: 44px",
):
    assert token in css, token

node = subprocess.run(["node", "--version"], capture_output=True, text=True)
if node.returncode == 0:
    match = re.search(r"<script id=\"mv922-android-touch-recovery\">(.*?)</script>", SCRIPT, re.S)
    assert match, "inline Android recovery script missing"
    with tempfile.NamedTemporaryFile("w", suffix=".js", encoding="utf-8") as handle:
        handle.write(match.group(1))
        handle.flush()
        subprocess.run(["node", "--check", handle.name], check=True, capture_output=True, text=True)

with tempfile.TemporaryDirectory() as td:
    app = Path(td)
    (app / "templates").mkdir()
    (app / "static").mkdir()
    (app / "data").mkdir()
    (app / "templates/index.html").write_text(source, encoding="utf-8")
    (app / "static/sw.js").write_text("const CACHE='unchanged';", encoding="utf-8")
    (app / "static/player.js").write_text("// player code unchanged", encoding="utf-8")
    before_sw = (app / "static/sw.js").read_bytes()
    before_js = (app / "static/player.js").read_bytes()
    patch_app(app)
    first = (app / "templates/index.html").read_bytes()
    patch_app(app)
    assert (app / "templates/index.html").read_bytes() == first
    assert (app / "static/sw.js").read_bytes() == before_sw
    assert (app / "static/player.js").read_bytes() == before_js
    assert (app / "static" / CSS).is_file()

print("PASS: Android document pan, scrolling, legacy-hook replacement, idempotency, inline JS syntax, and untouched player/service-worker assets.")
