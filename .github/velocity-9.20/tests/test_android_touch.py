from pathlib import Path
import sys, tempfile
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from patch_android_touch import patch_html, patch_app, CSS

src = '<html><head><meta name="viewport" content="width=980, initial-scale=0.5, user-scalable=no"><title>Music Vault</title></head><body><nav class="mobile-nav"></nav></body></html>'
a = patch_html(src)
assert a.count('name="viewport"') == 1
assert 'width=device-width, initial-scale=1, viewport-fit=cover' in a
assert 'width=980' not in a and 'user-scalable=no' not in a
assert a.count('mv920-android-touch-css') == 1
assert a.count('mv920-android-touch-detect') == 1
assert patch_html(a) == a
for old in ('mv919-android-touch-css', 'mv918-android-touch-css', 'mv917-android-touch-css', 'mv916-android-touch-css'):
    prior = a + f'<link id="{old}" href="old">'
    assert old not in patch_html(prior)
css = (Path(__file__).resolve().parents[1] / CSS).read_text(encoding='utf-8')
for token in ('touch-action: pan-x pan-y pinch-zoom !important', 'touch-action: auto !important', 'touch-action: manipulation !important', 'pointer-events: auto !important', 'min-height: 44px', 'html.mv920-android'):
    assert token in css
with tempfile.TemporaryDirectory() as td:
    root=Path(td); (root/'templates').mkdir(); (root/'static').mkdir(); (root/'data').mkdir()
    (root/'templates/index.html').write_text(src)
    (root/'static/sw.js').write_text("const CACHE='unchanged';")
    (root/'static/player.js').write_text('// player code unchanged')
    before_sw=(root/'static/sw.js').read_bytes(); before_js=(root/'static/player.js').read_bytes()
    patch_app(root); first=(root/'templates/index.html').read_bytes(); patch_app(root)
    assert (root/'templates/index.html').read_bytes() == first
    assert (root/'static/sw.js').read_bytes() == before_sw
    assert (root/'static/player.js').read_bytes() == before_js
    assert (root/'static'/CSS).is_file()
print('PASS: viewport is responsive, touch/scroll CSS is present, patch is idempotent, player JS and service worker are untouched.')
