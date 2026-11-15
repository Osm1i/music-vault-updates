from pathlib import Path
import hashlib
import os
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
FILES = [
    "install-update.sh",
    "patch_ambient_cards.py",
    "mv926-ambient-cards.css",
    "MUSIC_VAULT_RELEASE_VERSION.txt",
    "tests/test_ambient_cards.py",
    "tests/test_installer_e2e.py",
]


def write_executable(path: Path, content: str):
    path.write_text(content, encoding="utf-8")
    path.chmod(0o755)


def make_fixture(base: Path, fail_css: bool):
    package = base / "package"
    app = base / "app"
    mockbin = base / "mockbin"
    package.mkdir(parents=True)
    (app / "templates").mkdir(parents=True)
    (app / "static").mkdir(parents=True)
    (app / "data").mkdir(parents=True)
    mockbin.mkdir()

    for rel in FILES:
        target = package / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / rel, target)
    (package / "MUSIC_VAULT_RELEASE_VERSION.txt").write_text("9.26.2\n", encoding="utf-8")

    html = '''<!doctype html><html><head>
<link id="mv925-recent-picks-css" rel="stylesheet" href="/static/mv925-recent-picks.css?v=9.25.0">
<link id="mv920-android-touch-css" rel="stylesheet" href="/static/mv920-android-touch.css?v=9.20.0">
<title>Music Vault</title></head><body>
<section class="page active" id="page-home"><div class="mv81-mood-card"></div><div class="mv81-station-card"></div></section>
<script id="mv-consolidated-js" src="/static/mv-consolidated.js?v=8.5.0" defer></script>
</body></html>'''
    (app / "templates/index.html").write_text(html, encoding="utf-8")
    app_py = '''from pathlib import Path
def remux_webm_to_opus(path):
    args=['ffmpeg','-i',str(path),'-map','0:a:0','-vn','-c:a','copy','-map_metadata','0']
    return args
def process_job(row):
    opts={'format':'bestaudio/best','outtmpl':str(Path('/tmp')/'%(title)s.%(ext)s'),'noplaylist':False,'ignoreerrors':False,'quiet':True,'no_warnings':True,'continuedl':True,'overwrites':False,'postprocessors':[{'key':'FFmpegMetadata','add_metadata':True},{'key':'FFmpegThumbnailsConvertor','format':'jpg'}]}
    return opts
'''
    (app / "app.py").write_text(app_py, encoding="utf-8")
    (app / "static/mv-consolidated.js").write_text(
        "const mood='mv81-mood-card'; const station='mv81-station-card';", encoding="utf-8")
    (app / "static/sw.js").write_text("const CACHE='existing-sw';", encoding="utf-8")
    (app / "static/mv920-android-touch.css").write_text("/* existing Android touch fixes */", encoding="utf-8")
    (app / "static/mv925-recent-picks.css").write_text("/* existing Top Picks-style album rail */", encoding="utf-8")
    (app / "data/installed_version.txt").write_text("9.25.0\n", encoding="utf-8")

    entries = []
    for path in sorted(p for p in package.rglob("*") if p.is_file() and p.name != "SHA256SUMS_9_26_2.txt"):
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        entries.append(f"{digest}  {path.relative_to(package).as_posix()}\n")
    (package / "SHA256SUMS_9_26_2.txt").write_text("".join(entries), encoding="utf-8")

    write_executable(mockbin / "id", "#!/bin/sh\necho 0\n")
    write_executable(mockbin / "systemctl", """#!/bin/sh
case "$1" in
  is-active) echo active; exit 0 ;;
  restart) exit 0 ;;
  *) exit 0 ;;
esac
""")
    write_executable(mockbin / "chown", "#!/bin/sh\nexit 0\n")
    curl_mock = r'''#!/usr/bin/env python3
import os, sys
from pathlib import Path
args=sys.argv[1:]
out=Path(args[args.index("-o")+1])
url=next(arg for arg in args if arg.startswith("http://") or arg.startswith("https://"))
root=Path(os.environ["MV_TEST_APP_ROOT"])
if "/static/mv926-ambient-cards.css" in url:
    if os.environ.get("MV_TEST_FAIL_CSS") == "1":
        sys.exit(22)
    data=(root/"static/mv926-ambient-cards.css").read_bytes()
else:
    data=(root/"templates/index.html").read_bytes()
out.write_bytes(data)
'''
    write_executable(mockbin / "curl", curl_mock)

    env = os.environ.copy()
    env.update({
        "PATH": str(mockbin) + os.pathsep + env["PATH"],
        "MUSICVAULT_HOME": str(app),
        "MUSICVAULT_SERVICE": "music-vault.service",
        "MUSICVAULT_PORT": "8788",
        "MV_TEST_APP_ROOT": str(app),
    })
    if fail_css:
        env["MV_TEST_FAIL_CSS"] = "1"
    else:
        env.pop("MV_TEST_FAIL_CSS", None)
    return package, app, env


def run_install(base: Path, fail_css: bool):
    package, app, env = make_fixture(base, fail_css)
    before_app = (app / "app.py").read_bytes()
    before_template = (app / "templates/index.html").read_bytes()
    before_version = (app / "data/installed_version.txt").read_bytes()
    before_player = (app / "static/mv-consolidated.js").read_bytes()
    before_sw = (app / "static/sw.js").read_bytes()
    before_android = (app / "static/mv920-android-touch.css").read_bytes()
    before_recent = (app / "static/mv925-recent-picks.css").read_bytes()

    result = subprocess.run(
        ["bash", str(package / "install-update.sh")],
        cwd=package,
        env=env,
        capture_output=True,
        text=True,
        timeout=45,
    )
    combined = result.stdout + "\n" + result.stderr

    if fail_css:
        assert result.returncode != 0, "Forced live verification failure unexpectedly succeeded"
        assert "Restoring the backed-up app files" in combined, combined
        assert (app / "app.py").read_bytes() == before_app
        assert (app / "templates/index.html").read_bytes() == before_template
        assert (app / "data/installed_version.txt").read_bytes() == before_version
        assert not (app / "static/mv926-ambient-cards.css").exists()
        assert (app / "static/mv-consolidated.js").read_bytes() == before_player
        assert (app / "static/sw.js").read_bytes() == before_sw
        assert (app / "static/mv920-android-touch.css").read_bytes() == before_android
        assert (app / "static/mv925-recent-picks.css").read_bytes() == before_recent
        failure_record = app / "data/updates/last-install-failure-9.26.2.txt"
        assert failure_record.is_file(), "Rollback did not retain exact failure step/line"
        record = failure_record.read_text(encoding="utf-8")
        assert "step=" in record and "line=" in record and "backup=" in record
    else:
        assert result.returncode == 0, combined
        assert "SUCCESS:" in combined, combined
        assert (app / "data/installed_version.txt").read_text(encoding="utf-8").strip() == "9.26.2"
        updated_app = (app / "app.py").read_text(encoding="utf-8")
        for token in ("'format':'bestaudio/best'", "'concurrent_fragment_downloads':12", "'http_chunk_size':10*1024*1024", "'buffersize':1024*1024", "'-c:a','copy'"):
            assert token in updated_app, token
        updated_template = (app / "templates/index.html").read_text(encoding="utf-8")
        assert 'id="mv926-ambient-cards-css"' in updated_template
        assert 'mv925-recent-picks-css' in updated_template
        assert 'mv920-android-touch-css' in updated_template
        assert (app / "static/mv926-ambient-cards.css").is_file()
        assert (app / "static/mv-consolidated.js").read_bytes() == before_player
        assert (app / "static/sw.js").read_bytes() == before_sw
        assert (app / "static/mv920-android-touch.css").read_bytes() == before_android
        assert (app / "static/mv925-recent-picks.css").read_bytes() == before_recent


with tempfile.TemporaryDirectory(prefix="mv9262-e2e-") as td:
    base = Path(td)
    run_install(base / "success", fail_css=False)
    run_install(base / "rollback", fail_css=True)

print("PASS: full 9.26.2 installer simulation against Music Vault source layout: successful install, forced live-check failure, automatic rollback, exact failure record and preservation of Android touch, Recently Added, player JS and service worker assets.")
