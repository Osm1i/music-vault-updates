#!/usr/bin/env python3
"""Idempotent Android-only touch and scroll recovery patch for Music Vault 9.22.0."""
from pathlib import Path
import os
import re
import sys
import tempfile

VERSION = "9.22.0"
CSS = "mv922-android-touch.css"
VIEWPORT = '<meta id="mv922-viewport" name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">'
SCRIPT = r"""<script id="mv922-android-touch-recovery">(function(){
  try {
    if (!/Android/i.test(navigator.userAgent || "")) return;
    var scheduled = false;
    function repairScroll() {
      var html = document.documentElement;
      var body = document.body;
      if (!html || !body) return;
      html.classList.add("mv922-android");
      [html, body, document.scrollingElement].forEach(function(el) {
        if (!el) return;
        el.style.setProperty("touch-action", "pan-x pan-y pinch-zoom", "important");
        el.style.setProperty("overscroll-behavior-y", "auto", "important");
        el.style.setProperty("overflow-y", "auto", "important");
      });
      body.style.setProperty("overflow-x", "hidden", "important");
      body.style.setProperty("overflow-y", "auto", "important");
      body.style.setProperty("-webkit-overflow-scrolling", "touch", "important");
      var nodes = body.querySelectorAll("*");
      for (var i = 0; i < nodes.length; i++) {
        var el = nodes[i];
        if (!el || !el.getBoundingClientRect) continue;
        var rect = el.getBoundingClientRect();
        if (rect.height < 100 || rect.width < 40) continue;
        var style = window.getComputedStyle(el);
        if ((style.overflowY === "hidden" || style.overflowY === "clip") &&
            el.scrollHeight > el.clientHeight + 8) {
          el.style.setProperty("overflow-y", "auto", "important");
          el.style.setProperty("-webkit-overflow-scrolling", "touch", "important");
          el.style.setProperty("overscroll-behavior-y", "auto", "important");
          el.style.setProperty("touch-action", "pan-y pinch-zoom", "important");
        }
      }
    }
    function scheduleRepair() {
      if (scheduled) return;
      scheduled = true;
      window.requestAnimationFrame(function() {
        scheduled = false;
        repairScroll();
      });
    }
    function start() {
      repairScroll();
      if (window.MutationObserver && document.body) {
        new MutationObserver(scheduleRepair).observe(document.body, {
          childList: true,
          subtree: true
        });
      }
      window.addEventListener("pageshow", scheduleRepair, {passive:true});
      window.addEventListener("resize", scheduleRepair, {passive:true});
    }
    if (document.readyState === "loading") {
      document.addEventListener("DOMContentLoaded", start, {once:true});
    } else {
      start();
    }
  } catch (_) {}
})();</script>"""


def patch_html(source: str) -> str:
    source = re.sub(
        r'<meta\b(?=[^>]*\bname\s*=\s*["\']viewport["\'])[^>]*>',
        '',
        source,
        flags=re.I,
    )
    for version in ("922", "920", "919", "918", "917", "916"):
        source = re.sub(
            r'<script\b[^>]*id=["\']mv' + version +
            r'-android-touch-(?:detect|recovery)["\'][^>]*>.*?</script\s*>',
            '',
            source,
            flags=re.I | re.S,
        )
        source = re.sub(
            r'<link\b(?=[^>]*id=["\']mv' + version +
            r'-android-touch-css["\'])[^>]*>',
            '',
            source,
            flags=re.I,
        )
        source = re.sub(
            r'<meta\b(?=[^>]*id=["\']mv' + version +
            r'-viewport["\'])[^>]*>',
            '',
            source,
            flags=re.I,
        )
    block = VIEWPORT + SCRIPT + (
        f'<link id="mv922-android-touch-css" rel="stylesheet" '
        f'href="/static/{CSS}?v={VERSION}">'
    )
    if re.search(r'</head\s*>', source, re.I):
        return re.sub(r'</head\s*>', lambda m: block + m.group(0),
                      source, count=1, flags=re.I)
    raise RuntimeError("Cannot find </head> insertion point in templates/index.html")


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
    fd, name = tempfile.mkstemp(prefix="." + path.name + ".mv922-", dir=path.parent)
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
    css_source = Path(__file__).with_name(CSS)
    if not template.is_file() or not css_source.is_file():
        raise RuntimeError("Required template or stylesheet package file missing")
    html = patch_html(template.read_text(encoding="utf-8"))
    css = css_source.read_bytes()
    atomic_write(root / "static" / CSS, css)
    atomic_write(template, html.encode("utf-8"))
    print("PASS: Android touch recovery hook and scroll stylesheet registered once.")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("Usage: patch_android_touch.py APP_ROOT")
    try:
        patch_app(Path(sys.argv[1]).resolve())
    except Exception as exc:
        raise SystemExit("PATCH ERROR: " + str(exc))
