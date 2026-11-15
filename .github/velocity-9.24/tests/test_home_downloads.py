from pathlib import Path
import importlib.util
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from patch_home_downloads import patch_html, patch_download_options, patch_app, JS_FILE, CSS_FILE

html_source = '''<!doctype html><html><head>
<meta id="mv920-viewport" name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<link id="mv920-android-touch-css" rel="stylesheet" href="/static/mv920-android-touch.css?v=9.20.0">
<title>Music Vault</title></head><body>
<div id="page-home" class="page active"><section class="music-section"><div class="section-title"><div><h2>Recently Added</h2></div><button class="text-action">View all ›</button></div><div id="recentAlbums" class="music-rail"></div></section></div>
<nav class="mobile-nav"><button data-page="home">Listen Now</button><button data-page="new">New</button><button data-page="radio">Radio</button><button data-page="library">Library</button><button data-page="search">Search</button></nav>
<script id="mv-consolidated-js" src="/static/mv-consolidated.js"></script>
<script id="mv923-player-controls-js" src="/static/mv923-player-controls.js"></script>
</body></html>'''
app_source = '''import os
from yt_dlp import YoutubeDL

def process_job():
 if kind=='url':
  opts={'format':'bestaudio/best','outtmpl':'%(title)s.%(ext)s','noplaylist':False,'ignoreerrors':False,'quiet':True,'no_warnings':True,'continuedl':True,'overwrites':False,'postprocessors':[{'key':'FFmpegMetadata'}]}
  with YoutubeDL(opts) as y: info=y.extract_info(src,download=True)
'''

patched_html = patch_html(html_source)
assert patched_html.count('id="mv924-home-repair-css"') == 1
assert patched_html.count('id="mv924-home-repair-js"') == 1
assert 'id="mv920-android-touch-css"' in patched_html
assert 'id="mv-consolidated-js"' in patched_html
assert 'id="mv923-player-controls-js"' in patched_html
assert 'data-page="new"' in patched_html and 'data-page="radio"' in patched_html
assert 'data-page="library"' in patched_html and 'data-page="search"' in patched_html
assert patch_html(patched_html) == patched_html

patched_app = patch_download_options(app_source)
for token in ("'concurrent_fragment_downloads':8", "'http_chunk_size':10*1024*1024", "'buffersize':1024*1024", "'format':'bestaudio/best'"):
    assert token in patched_app, token
assert patch_download_options(patched_app) == patched_app
assert "'format':'bestaudio/best'" in patched_app

js = (ROOT / JS_FILE).read_text(encoding='utf-8')
css = (ROOT / CSS_FILE).read_text(encoding='utf-8')
for token in ('#page-home #recentAlbums.mv710-recent-grid', 'display: grid !important', 'grid-template-columns: repeat(2, minmax(0, 1fr))'):
    assert token in css, token
for token in ('openRecentlyAddedAlbums', "openLibraryHubCategory('albums')", 'isBenignDetachedObjectError', 'The object can not be found here', 'window.mv923ClearPlayer', 'MusicVault710?.renderHomeAlbums', 'MusicVault924'):
    assert token in js, token

node = subprocess.run(['node', '--version'], capture_output=True, text=True)
if node.returncode == 0:
    subprocess.run(['node', '--check', str(ROOT / JS_FILE)], check=True)

with tempfile.TemporaryDirectory() as td:
    app = Path(td) / 'app'
    (app / 'templates').mkdir(parents=True)
    (app / 'static').mkdir()
    (app / 'data').mkdir()
    (app / 'templates/index.html').write_text(html_source, encoding='utf-8')
    (app / 'app.py').write_text(app_source, encoding='utf-8')
    for name, content in (
        ('mv-consolidated.js', '// existing playback code'),
        ('mv-consolidated.css', '/* existing style */'),
        ('sw.js', "const CACHE='unchanged';"),
        ('mv923-player-controls.js', '// existing 9.23 player controls'),
        ('mv923-player-controls.css', '/* existing 9.23 player styles */'),
    ):
        (app / 'static' / name).write_text(content, encoding='utf-8')
    before = {p.name: p.read_bytes() for p in (app / 'static').iterdir()}

    package = Path(td) / 'package'
    package.mkdir()
    for file in (ROOT / 'patch_home_downloads.py', ROOT / JS_FILE, ROOT / CSS_FILE):
        shutil.copy2(file, package / file.name)
    spec = importlib.util.spec_from_file_location('mv924_patcher_copy', package / 'patch_home_downloads.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.patch_app(app)
    first_template = (app / 'templates/index.html').read_bytes()
    first_app = (app / 'app.py').read_bytes()
    module.patch_app(app)
    assert (app / 'templates/index.html').read_bytes() == first_template
    assert (app / 'app.py').read_bytes() == first_app
    for name, original in before.items():
        assert (app / 'static' / name).read_bytes() == original, name
    assert (app / 'static' / JS_FILE).is_file()
    assert (app / 'static' / CSS_FILE).is_file()
    compile((app / 'app.py').read_text(encoding='utf-8'), str(app / 'app.py'), 'exec')

print('PASS: Home Recent Added grid specificity, See All -> Albums routing, exact Safari NotFoundError suppression, primary tab markup retention, faster yt-dlp settings, idempotency, Python syntax, and untouched existing playback/service-worker assets.')
