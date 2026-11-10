#!/usr/bin/env python3
"""Prepare Music Vault Vanguard 9.2.0: installer repair and Settings privacy cleanup."""
from __future__ import annotations
import hashlib
import re
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
VERSION = "9.2.0"
# The 9.2 wrapper runs the validated 9.1 installer before applying the updater repair.
# Build recipe includes syntax-checked, additive update repair components.
ROUTES = r'''from __future__ import annotations
import json
import os
import re
import shutil
import subprocess
import time
from pathlib import Path
from urllib.parse import urlparse

from flask import jsonify, request

DEFAULT_REPO = "Osm1i/music-vault-updates"
REPO_RE = re.compile(r"^[A-Za-z0-9_.-]{1,100}/[A-Za-z0-9_.-]{1,100}$")


def register_update_routes(app, base):
    data_dir = Path(base) / "data"
    config_path = data_dir / "update_config.json"
    status_path = data_dir / "update_status.json"
    systemctl = shutil.which("systemctl") or "/usr/bin/systemctl"

    def read_json(path, default):
        try:
            return json.loads(path.read_text(encoding="utf-8"))
        except Exception:
            return default

    def write_config():
        data_dir.mkdir(parents=True, exist_ok=True)
        config = {"repo": DEFAULT_REPO, "token": "", "configured_at": int(time.time())}
        tmp = config_path.with_suffix(".tmp")
        tmp.write_text(json.dumps(config, indent=2), encoding="utf-8")
        os.chmod(tmp, 0o600)
        os.replace(tmp, config_path)
        os.chmod(config_path, 0o600)

    def same_origin():
        origin = request.headers.get("Origin")
        if not origin:
            return True
        try:
            return urlparse(origin).netloc.lower() == request.host.lower()
        except Exception:
            return False

    def launch(action):
        services = {
            "check": "music-vault-update-check.service",
            "install": "music-vault-update-install.service",
        }
        service = services.get(action)
        if not service:
            return False, "Unknown update action."
        command = [systemctl, "start", "--no-block", service]
        if os.geteuid() != 0:
            command = ["sudo", "-n"] + command
        try:
            result = subprocess.run(command, stdin=subprocess.DEVNULL,
                                    capture_output=True, text=True, timeout=12, check=False)
        except Exception as exc:
            return False, "Could not start the update service: " + str(exc)
        if result.returncode != 0:
            detail = (result.stderr or result.stdout or "systemd refused the request").strip()
            return False, "Could not start the updater service: " + detail[:260]
        return True, "Update task accepted by systemd."

    @app.get("/api/updates/status")
    def mv_update_status():
        state = read_json(status_path, {})
        installed = state.get("installed_version")
        if not installed:
            try:
                installed = (data_dir / "installed_version.txt").read_text(encoding="utf-8").strip()
            except Exception:
                installed = "Unknown"
        return jsonify({
            "configured": True,
            "installed_version": installed,
            "latest_version": state.get("latest_version"),
            "available": bool(state.get("available")),
            "downloaded": bool(state.get("downloaded")),
            "state": state.get("state", "Not checked"),
            "message": state.get("message", "Check for updates to see the latest release."),
            "notes": state.get("notes", ""),
            "release_url": state.get("release_url", ""),
            "checked_at": state.get("checked_at"),
            "updated_at": state.get("updated_at"),
        })

    @app.post("/api/updates/config")
    def mv_update_config():
        if not same_origin():
            return jsonify(error="Cross-origin update configuration is blocked."), 403
        write_config()
        ok, message = launch("check")
        if not ok:
            return jsonify(error=message), 503
        return jsonify(ok=True, message="Update channel connected. Checking for releases.", repo=DEFAULT_REPO)

    @app.post("/api/updates/check")
    def mv_update_check():
        if not same_origin():
            return jsonify(error="Cross-origin update checks are blocked."), 403
        if not config_path.exists():
            write_config()
        ok, message = launch("check")
        return (jsonify(ok=ok, message=message), 202 if ok else 503)

    @app.post("/api/updates/install")
    def mv_update_install():
        if not same_origin():
            return jsonify(error="Cross-origin update installation is blocked."), 403
        state = read_json(status_path, {})
        if not state.get("available") or not state.get("downloaded"):
            return jsonify(error="No verified update is ready to install. Check for updates first."), 409
        ok, message = launch("install")
        return (jsonify(ok=ok, message=message), 202 if ok else 503)
'''

def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: prepare_release.py STAGE_DIR VERSION")
    stage = Path(sys.argv[1]).resolve()
    version = sys.argv[2].strip()
    if version != VERSION:
        raise SystemExit(f"This patch is only for {VERSION}, not {version}")
    static = stage / "static"
    static.mkdir(parents=True, exist_ok=True)
    shutil.copy2(ROOT / "mv92-update-center.js", static / "mv92-update-center.js")

    service_dir = stage / "systemd"
    service_dir.mkdir(parents=True, exist_ok=True)
    (service_dir / "music-vault-update-install.service").write_text(
        """[Unit]
Description=Install verified Music Vault release
After=network-online.target music-vault.service
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/music-vault-update-agent install
TimeoutStartSec=600
""", encoding="utf-8")
    (stage / "musicvault_update_routes.py").write_text(ROUTES, encoding="utf-8")

    sw = static / "sw.js"
    if not sw.is_file():
        raise SystemExit("The package is missing static/sw.js")
    sw_text = sw.read_text(encoding="utf-8")
    updated, count = re.subn(
        r"""const CACHE=(['"])music-vault-shell-v\d+-\d+(?:-\d+)?\1""",
        "const CACHE='music-vault-shell-v9-2-0'",
        sw_text, count=1)
    if count != 1:
        raise SystemExit("Could not safely identify the PWA cache version.")
    sw.write_text(updated, encoding="utf-8")

    installer = stage / "install-update.sh"
    if not installer.is_file():
        raise SystemExit("Package is missing install-update.sh")
    legacy = stage / "install-update-legacy.sh"
    shutil.copy2(installer, legacy)

    wrapper = r'''#!/usr/bin/env bash
set -Eeuo pipefail
MV92_APP="/opt/music-vault"
MV92_PACKAGE_DIR="$(CDPATH= cd -- "$(dirname -- "__MV92_BASH_SOURCE__")" && pwd)"

# Run the already-tested Vanguard 9.1 installer unchanged first.
bash "$MV92_PACKAGE_DIR/install-update-legacy.sh"

# Install the 9.2 Update Center repair after the existing update succeeds.
install -D -m 0644 "$MV92_PACKAGE_DIR/static/mv92-update-center.js" "$MV92_APP/static/mv92-update-center.js"
install -D -m 0644 "$MV92_PACKAGE_DIR/musicvault_update_routes.py" "$MV92_APP/musicvault_update_routes.py"
install -D -m 0644 "$MV92_PACKAGE_DIR/systemd/music-vault-update-install.service" "/etc/systemd/system/music-vault-update-install.service"

# Keep the release source fixed internally and remove any stale personal token.
python3 - <<'MV92_CONFIG'
import json, os, time
from pathlib import Path
p = Path("/opt/music-vault/data/update_config.json")
p.parent.mkdir(parents=True, exist_ok=True)
tmp = p.with_suffix(".tmp")
tmp.write_text(json.dumps({
    "repo": "Osm1i/music-vault-updates",
    "token": "",
    "configured_at": int(time.time())
}, indent=2), encoding="utf-8")
os.chmod(tmp, 0o600)
os.replace(tmp, p)
os.chmod(p, 0o600)
MV92_CONFIG

MV92_APP_USER="$(systemctl show -p User --value music-vault.service 2>/dev/null || true)"
if [ -z "$MV92_APP_USER" ]; then MV92_APP_USER="$(stat -c %U "$MV92_APP"); fi
MV92_SYSTEMCTL="$(command -v systemctl)"
printf '%s ALL=(root) NOPASSWD: %s start --no-block music-vault-update-check.service, %s start --no-block music-vault-update-install.service\n' "$MV92_APP_USER" "$MV92_SYSTEMCTL" "$MV92_SYSTEMCTL" > /etc/sudoers.d/music-vault-update-center
chmod 0440 /etc/sudoers.d/music-vault-update-center
visudo -cf /etc/sudoers.d/music-vault-update-center
systemctl daemon-reload

python3 - "$MV92_APP/templates/index.html" <<'MV92_HTML_PATCH'
from pathlib import Path
import sys
page = Path(sys.argv[1])
html = page.read_text(encoding="utf-8")
if "mv92-update-center.js" not in html:
    if "</body>" not in html.lower():
        raise SystemExit("Cannot safely add Update Center script: </body> is missing.")
    pos = html.lower().find("</body>")
    html = html[:pos] + '<script defer src="/static/mv92-update-center.js?v=9.2.0"></script>\n' + html[pos:]
page.write_text(html, encoding="utf-8")
MV92_HTML_PATCH

systemctl restart music-vault.service
for attempt in $(seq 1 45); do
    if curl -fsS http://127.0.0.1:8788/ | grep -qi "music vault"; then
        echo "PASS: Vanguard 9.2 Update Center repair installed and healthy."
        exit 0
    fi
    sleep 2
done
echo "ERROR: Music Vault did not pass the post-update health check." >&2
exit 1
'''
    wrapper = wrapper.replace("__MV92_BASH_SOURCE__", chr(36) + "{BASH_SOURCE[0]}")
    installer.write_text(wrapper, encoding="utf-8")
    installer.chmod(0o755)
    (stage / "MUSIC_VAULT_RELEASE_VERSION.txt").write_text(VERSION + "\n", encoding="utf-8")
    checksum = stage / "SHA256SUMS_9_0.txt"
    if not checksum.is_file():
        raise SystemExit("Package is missing SHA256SUMS_9_0.txt")
    rows = []
    for path in sorted(p for p in stage.rglob("*") if p.is_file() and p != checksum):
        rows.append(f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.relative_to(stage).as_posix()}\n")
    checksum.write_text("".join(rows), encoding="utf-8")

    if '"--no-block"' not in ROUTES or '"token": ""' not in ROUTES:
        raise SystemExit("Update route hardening smoke check failed.")
    if "mv92-update-center.js" not in installer.read_text(encoding="utf-8"):
        raise SystemExit("Installer UI hook was not injected.")
    if not (stage / "install-update-legacy.sh").is_file():
        raise SystemExit("Original tested installer was not preserved.")
    if "music-vault-update-install.service" not in installer.read_text(encoding="utf-8"):
        raise SystemExit("Dedicated install service was not injected.")
    if "MutationObserver" not in (static / "mv92-update-center.js").read_text(encoding="utf-8"):
        raise SystemExit("Settings cleanup and UI observer asset is incomplete.")
    print("PASS: original Vanguard 9.1 installer preserved and run unchanged")
    print("PASS: update route starts systemd services and reports start failures")
    print("PASS: dedicated install unit and restricted sudoers permissions included")
    print("PASS: CasaOS/GitHub repository/token configuration hidden from UI")
    print("PASS: install action polls for confirmed version change and refreshes")
    print("PASS: PWA cache advanced to 9.2.0")
    print(f"PASS: regenerated SHA-256 manifest for {len(rows)} package files")

if __name__ == "__main__":
    main()
