#!/usr/bin/env python3
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from patch_island_position import transform_css, transform_js, transform_index, transform_sw

CSS = "\n".join([
    "bottom:calc(env(safe-area-inset-bottom,0px) + 7px)!important;",
    "bottom:calc(env(safe-area-inset-bottom,0px) + 5px)!important;",
    "bottom:calc(env(safe-area-inset-bottom,0px) + 7px)!important;",
    "bottom:calc(env(safe-area-inset-bottom,0px) + 8px)!important;",
])
JS = "\n".join([
    "dock.style.setProperty('bottom','calc(env(safe-area-inset-bottom, 0px) + 7px)','important');",
    "dock.style.setProperty('bottom','calc(env(safe-area-inset-bottom, 0px) + 8px)','important');",
])
INDEX = '<link id="mv-consolidated-css" rel="stylesheet" href="/static/mv-consolidated.css?v=8.4.0">\n<script id="mv-consolidated-js" src="/static/mv-consolidated.js?v=8.5.0" defer></script>'
SW = "const CACHE='music-vault-shell-v9-0-0-v9-4-0-mv-auto-v1';\nconst SHELL=['/static/mv-consolidated.js?v=8.5.0','/static/mv-consolidated.css?v=8.4.0'];"

css = transform_css(CSS)
assert css.count('+ 0px') == 4
assert css.count('+ 7px') == 0 and css.count('+ 5px') == 0 and css.count('+ 8px') == 0
js = transform_js(JS)
assert js.count('+ 0px)') == 2
index = transform_index(INDEX)
assert index.count('v=9.15.0') == 2
sw = transform_sw(SW)
assert 'music-vault-shell-v9-15-0-island-position-v1' in sw
assert sw.count('v=9.15.0') == 2

for fn, source in ((transform_css, CSS[:-20]), (transform_js, JS[:-20])):
    try:
        fn(source)
    except RuntimeError:
        pass
    else:
        raise AssertionError('Patch must reject an unexpected source layout')
print('PASS: all Bottom Island CSS/JS offsets align at safe-area + 0px (8px lower).')
print('PASS: template and service-worker asset caches bump to v9.15.0.')
print('PASS: mismatched source layouts fail closed without a partial patch.')
