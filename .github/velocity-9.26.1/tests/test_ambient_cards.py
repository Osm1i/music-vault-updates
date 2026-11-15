from pathlib import Path
import subprocess
import importlib.util
import shutil
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
INSTALLER = (ROOT / 'install-update.sh').read_text(encoding='utf-8')
assert (chr(92) + chr(36) + chr(123)) not in INSTALLER, 'installer contains escaped shell variable expansion'
assert ('APP_ROOT="' + chr(36) + '{MUSICVAULT_HOME:-/opt/music-vault}"') in INSTALLER
assert ('dirname -- "' + chr(36) + '{BASH_SOURCE[0]}') in INSTALLER
assert '9.26.1' in INSTALLER
assert 'node --check' not in INSTALLER
probe_code = 'APP_ROOT="' + chr(36) + '{MUSICVAULT_HOME:-/opt/music-vault}"; printf "%s\\n" "$APP_ROOT"'
probe = subprocess.run(['bash', '-c', probe_code], env={**__import__('os').environ, 'MUSICVAULT_HOME':'/tmp/music-vault-install-probe'}, capture_output=True, text=True, check=True)
assert probe.stdout.strip() == '/tmp/music-vault-install-probe', probe.stdout
sys.path.insert(0, str(ROOT))
from patch_ambient_cards import patch_html, patch_download_options, patch_app, CSS_FILE, CSS_ID

html_source = '''<!doctype html><html><head>
<link id="mv925-recent-picks-css" rel="stylesheet" href="/static/mv925-recent-picks.css?v=9.25.0">
<link rel="stylesheet" href="/static/mv-consolidated.css">
</head><body><main id="page-home" class="page active"><div id="recentAlbums"></div></main>
<script id="mv-consolidated-js" src="/static/mv-consolidated.js?v=8.5.0" defer></script>
</body></html>'''

app_source = '''from yt_dlp import YoutubeDL

def process_job(row):
 if kind=='url':
  opts={'format':'bestaudio/best','concurrent_fragment_downloads':8,'http_chunk_size':10*1024*1024,'buffersize':1024*1024,'outtmpl':'%(title)s.%(ext)s','postprocessors':[{'key':'FFmpegMetadata','add_metadata':True},{'key':'FFmpegThumbnailsConvertor','format':'jpg'}]}
  with YoutubeDL(opts) as y: info=y.extract_info(src,download=True)
'''

patched_html = patch_html(html_source)
assert patched_html.count(f'id="{CSS_ID}"') == 1
assert 'mv925-recent-picks-css' in patched_html
assert 'mv-consolidated.css' in patched_html
assert 'mv-consolidated.js' in patched_html
assert patch_html(patched_html) == patched_html

patched_app = patch_download_options(app_source)
assert "'format':'bestaudio/best'" in patched_app
assert "'concurrent_fragment_downloads':12" in patched_app
assert "'http_chunk_size':10*1024*1024" in patched_app
assert "'buffersize':1024*1024" in patched_app
assert "'key':'FFmpegMetadata'" in patched_app
assert "'key':'FFmpegThumbnailsConvertor'" in patched_app
assert patch_download_options(patched_app) == patched_app

legacy_app = "opts={'format':'bestaudio/best','outtmpl':'%(title)s.%(ext)s','postprocessors':[{'key':'FFmpegMetadata'}]}\n"
legacy_patched = patch_download_options(legacy_app)
assert "'concurrent_fragment_downloads':12" in legacy_patched
assert "'http_chunk_size':10*1024*1024" in legacy_patched
assert "'buffersize':1024*1024" in legacy_patched
assert patch_download_options(legacy_patched) == legacy_patched

css = (ROOT / CSS_FILE).read_text(encoding='utf-8')
for token in (
    '.mv81-mood-card', '.mv81-station-card', 'mv926-aurora', 'mv926-sheen',
    'mv926-orbit', 'mv926-equalizer', 'prefers-reduced-motion: reduce',
    'pointer-events: none', '--mv926-a',
):
    assert token in css, token
assert '.mv81-album' not in css
assert '#mvBottomIsland' not in css

with tempfile.TemporaryDirectory() as td:
    app = Path(td) / 'app'
    (app / 'templates').mkdir(parents=True)
    (app / 'static').mkdir()
    (app / 'data').mkdir()
    (app / 'templates/index.html').write_text(html_source, encoding='utf-8')
    (app / 'app.py').write_text(app_source, encoding='utf-8')
    for name, content in (
        ('mv-consolidated.js', '// existing Home renderer and handlers'),
        ('mv-consolidated.css', '/* existing app styles */'),
        ('mv925-recent-picks.css', '/* v9.25 layout remains */'),
        ('sw.js', "const CACHE='unchanged';"),
    ):
        (app / 'static' / name).write_text(content, encoding='utf-8')
    before = {p.name: p.read_bytes() for p in (app / 'static').iterdir()}
    package = Path(td) / 'package'
    package.mkdir()
    for f in (ROOT / 'patch_ambient_cards.py', ROOT / CSS_FILE):
        shutil.copy2(f, package / f.name)
    spec = importlib.util.spec_from_file_location('mv926_patch_copy', package / 'patch_ambient_cards.py')
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    mod.patch_app(app)
    first_template = (app / 'templates/index.html').read_bytes()
    first_app = (app / 'app.py').read_bytes()
    mod.patch_app(app)
    assert (app / 'templates/index.html').read_bytes() == first_template
    assert (app / 'app.py').read_bytes() == first_app
    assert all((app / 'static' / n).read_bytes() == b for n, b in before.items())
    assert (app / 'static' / CSS_FILE).is_file()
    compile((app / 'app.py').read_text(encoding='utf-8'), str(app / 'app.py'), 'exec')

print('PASS: ambient mood/station cards, reduced-motion fallback, original Home renderer/layout preservation, best-audio format, 12-way fragment concurrency, chunk/buffer settings, metadata processing, idempotency and untouched original static assets.')
