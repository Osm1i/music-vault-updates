from pathlib import Path
import importlib.util
import re
import shutil
import subprocess
import sys
import tempfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from patch_player_controls import patch_html, patch_app, JS_FILE, CSS_FILE

ROOT = Path(__file__).resolve().parents[1]

# Minimal source-shaped fixture using the exact anchors from the standalone player.
source = '''<!doctype html>
<html><head>
<meta id="mv922-viewport" name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<script id="mv922-android-touch-recovery">document.documentElement.classList.add('mv922-android');</script>
<link id="mv922-android-touch-css" rel="stylesheet" href="/static/mv922-android-touch.css?v=9.22.0">
<title>Music Vault</title></head><body>
<div class="playerbar" id="miniPlayer"><div class="playerleft" onclick="openNowPlaying()"><div class="playerart"></div><div class="playerlabel"><strong id="miniTitle">Choose something to play</strong><small id="miniArtist">Your library</small></div><button class="mini-like" id="miniLike" onclick="event.stopPropagation();toggleCurrentFavorite()" title="Favorite">♡</button></div></div>
<audio id="mvAudio"></audio>
<script id="music-vault-standalone-player">
(()=>{
const A=$('mvAudio'); if(!A)return;
let queue=[],currentIndex=-1,shuffle=false,repeatMode='off',duration=0,lyricsRows=[],lyricsTimer=null;
const store=()=>{localStorage.setItem('player',JSON.stringify({queue,currentIndex}))};
function updateButtons(){}
function renderQueue(){}
function paint(){let t=current();if(!t){$('miniTitle').textContent='Choose something to play';$('miniArtist').textContent='Your library · Music Vault Player';$('nowTitle').textContent='Nothing playing';$('nowArtist').textContent='Choose a song from your library';setImage($('miniArt'),$('miniArtFallback'),null);setImage($('nowArt'),$('nowArtFallback'),null);updateButtons();return}
$('miniTitle').textContent=t.title;$('miniArtist').textContent=t.artist+' · '+t.album;$('nowTitle').textContent=t.title;$('nowArtist').textContent=t.artist;$('npSource').textContent=t.album||'YOUR LIBRARY';setImage($('miniArt'),$('miniArtFallback'),t);setImage($('nowArt'),$('nowArtFallback'),t);$('npBackdrop').style.backgroundImage='url("'+artUrl(t)+'")';$('miniLike').textContent='♡';$('nowFavorite').textContent='♡';renderQueue();loadLyrics(t.id);updateButtons();}
window.mvRemoveQueueIndex=i=>{queue.splice(i,1);renderQueue();store()};
window.playTracks=(items,index=0,append=false)=>{queue=items;};
})();
</script>
</body></html>'''

patched = patch_html(source)
assert patched.count('id="miniClear"') == 1
assert 'aria-label="Stop and clear song"' in patched
assert patched.count('id="mv923-player-controls-css"') == 1
assert patched.count('id="mv923-player-controls-js"') == 1
assert patched.count('window.mv923ClearPlayer=()=>') == 1
assert "$('miniPlayer').hidden=true;" in patched
assert "$('miniPlayer').hidden=false;" in patched
assert 'window.mv923SyncFavoriteState?.(t.id);' in patched
assert "classList.remove('is-favorite')" in patched
assert "setAttribute('aria-pressed','false')" in patched
assert 'mv922-android-touch-css' in patched  # Existing Android fixes stay intact.
assert 'mv922-android-touch-recovery' in patched
assert patch_html(patched) == patched

# The clear action resets in-memory/local player state and does not delete audio/library files.
clear_match = re.search(r'window\.mv923ClearPlayer=\(\)=>\{(.*?)\n\};', patched, re.S)
assert clear_match
clear_body = clear_match.group(1)
for token in ('queue.length=0', 'currentIndex=-1', 'A.pause()', "A.removeAttribute('src')", 'A.load()', 'renderQueue()', 'paint()', 'store()', 'closeNowPlaying'):
    assert token in clear_body, token
for forbidden in ('DELETE FROM', '/api/delete', 'unlink(', 'remove_file', 'os.remove'):
    assert forbidden not in clear_body

js = (ROOT / JS_FILE).read_text(encoding='utf-8')
css = (ROOT / CSS_FILE).read_text(encoding='utf-8')
for token in ('/api/personal/', '/favorites', 'aria-pressed', 'is-favorite', 'mv923SyncFavoriteState', 'syncVisibleFavoriteButtons', 'MutationObserver', 'mv923RefreshFavoriteStates'):
    assert token in js, token
for token in ('#miniLike.is-favorite', '#nowFavorite.is-favorite', '#8e8e93', '#ff375f', '.mini-clear', '#miniPlayer[hidden]'):
    assert token in css, token

node = subprocess.run(['node', '--version'], capture_output=True, text=True)
if node.returncode == 0:
    subprocess.run(['node', '--check', str(ROOT / JS_FILE)], check=True)

# Run the actual patcher against a copy of the fixture and verify idempotency and scope.
with tempfile.TemporaryDirectory() as td:
    app = Path(td) / 'app'
    (app / 'templates').mkdir(parents=True)
    (app / 'static').mkdir()
    (app / 'data').mkdir()
    (app / 'templates/index.html').write_text(source, encoding='utf-8')
    (app / 'app.py').write_text('# backend unchanged\n', encoding='utf-8')
    (app / 'static/sw.js').write_text("const CACHE='unchanged';", encoding='utf-8')
    (app / 'static/mv-consolidated.js').write_text('// playback bundle unchanged', encoding='utf-8')
    before_app = (app / 'app.py').read_bytes()
    before_sw = (app / 'static/sw.js').read_bytes()
    before_player_js = (app / 'static/mv-consolidated.js').read_bytes()

    helper = Path(td) / 'package'
    helper.mkdir()
    shutil.copy2(ROOT / 'patch_player_controls.py', helper / 'patch_player_controls.py')
    shutil.copy2(ROOT / JS_FILE, helper / JS_FILE)
    shutil.copy2(ROOT / CSS_FILE, helper / CSS_FILE)
    spec = importlib.util.spec_from_file_location('patch_player_controls_copy', helper / 'patch_player_controls.py')
    helper_module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(helper_module)
    helper_module.patch_app(app)
    once = (app / 'templates/index.html').read_bytes()
    helper_module.patch_app(app)
    assert (app / 'templates/index.html').read_bytes() == once
    assert (app / 'static/sw.js').read_bytes() == before_sw
    assert (app / 'app.py').read_bytes() == before_app
    assert (app / 'static/mv-consolidated.js').read_bytes() == before_player_js
    assert (app / 'static' / JS_FILE).is_file()
    assert (app / 'static' / CSS_FILE).is_file()

print('PASS: profile-aware favorite state; clear X stops audio, empties queue and clears saved player state; idempotent patch; backend, playback bundle and service worker unchanged.')
