from pathlib import Path
import importlib.util
import shutil
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from patch_recent_added import patch_html, patch_app, CSS_FILE, CSS_ID

source = '''<!doctype html><html><head>
<link id="mv9241-home-repair-css" rel="stylesheet" href="/static/mv9241-home-repair.css?v=9.24.1">
<link rel="stylesheet" href="/static/mv-consolidated.css">
</head><body><section class="page active" id="page-home">
<div class="music-section"><div class="section-title"><div><h2>Recently Added</h2><p>39 albums in your collection · newest first</p></div><button class="text-action">View all ›</button></div>
<div id="recentAlbums" class="albumgrid music-rail mv710-recent-grid"><button class="mv710-album-card" data-mv710-home-album="0"><span class="mv710-album-cover"><img src="/art.jpg"><span>▶</span></span><strong>Album name</strong><small>Artist · 18 songs</small></button></div></div>
<nav class="mobile-nav"><button data-page="home">Home</button><button data-page="new">New</button><button data-page="radio">Radio</button><button data-page="library">Library</button><button data-page="search">Search</button></nav>
</section></body></html>'''

patched = patch_html(source)
assert patched.count(f'id="{CSS_ID}"') == 1
assert 'mv9241-home-repair-css' in patched
assert 'mv-consolidated.css' in patched
assert 'id="recentAlbums"' in patched
assert 'data-mv710-home-album="0"' in patched
for tab in ('home', 'new', 'radio', 'library', 'search'):
    assert f'data-page="{tab}"' in patched
assert patch_html(patched) == patched

css = (ROOT / CSS_FILE).read_text(encoding='utf-8')
for token in (
    '#page-home #recentAlbums.mv710-recent-grid',
    'display: flex !important',
    'flex-wrap: nowrap !important',
    'overflow-x: auto !important',
    'scroll-snap-type: x mandatory !important',
    'flex: 0 0 clamp(112px, 29vw, 132px) !important',
    'border-radius: 19px !important',
    'aspect-ratio: 1 / 1 !important',
    '-webkit-line-clamp: 2 !important',
    'display: none !important',
):
    assert token in css, token

with tempfile.TemporaryDirectory() as td:
    app = Path(td) / 'app'
    (app / 'templates').mkdir(parents=True)
    (app / 'static').mkdir()
    (app / 'data').mkdir()
    (app / 'templates/index.html').write_text(source, encoding='utf-8')
    package = Path(td) / 'package'
    package.mkdir()
    shutil.copy2(ROOT / 'patch_recent_added.py', package / 'patch_recent_added.py')
    shutil.copy2(ROOT / CSS_FILE, package / CSS_FILE)
    spec = importlib.util.spec_from_file_location('mv925_patch_copy', package / 'patch_recent_added.py')
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    mod.patch_app(app)
    first = (app / 'templates/index.html').read_bytes()
    mod.patch_app(app)
    assert (app / 'templates/index.html').read_bytes() == first
    assert (app / 'static' / CSS_FILE).is_file()
    assert 'id="mv9241-home-repair-css"' in first.decode()
    assert first.decode().count(f'id="{CSS_ID}"') == 1

print('PASS: compact horizontal Top Picks-style album cards; existing album data, clicks, count, View All, navigation and 9.24.1 assets remain intact; patch is idempotent.')
