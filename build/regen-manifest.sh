#!/usr/bin/env bash
# regen-manifest.sh — regenerate build/expected-injected.sha256 after editing
# any file under image/. Run this BEFORE building; a stale manifest fails the
# build's verification step on purpose.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE/.."
python3 - <<'PY'
import hashlib, os
files = [
    ("etc/mmdvmhost", "image/configs/mmdvmhost"),
    ("etc/dmrgateway", "image/configs/dmrgateway"),
    ("etc/aprsgateway", "image/configs/aprsgateway"),
    ("etc/wpa_supplicant/wpa_supplicant.conf", "image/configs/wpa_supplicant.conf"),
    ("usr/local/sbin/hotspot-oled-dash.py", "image/scripts/hotspot-oled-dash.py"),
    ("usr/local/sbin/hotspot-config-guard.sh", "image/scripts/hotspot-config-guard.sh"),
    ("usr/local/sbin/hotspot-display-assert.sh", "image/scripts/hotspot-display-assert.sh"),
    ("etc/systemd/system/hotspot-oled.service", "image/systemd/hotspot-oled.service"),
    ("etc/systemd/system/hotspot-config-guard.service", "image/systemd/hotspot-config-guard.service"),
    ("etc/systemd/system/mmdvmhost.service.d/10-mortemhive-guard.conf", "image/systemd/mmdvmhost-guard.conf"),
    ("etc/systemd/system/dmrgateway.service.d/10-mortemhive-guard.conf", "image/systemd/dmrgateway-guard.conf"),
    ("etc/systemd/system.conf.d/watchdog.conf", "image/systemd/watchdog.conf"),
    ("etc/sysctl.d/99-wedge-autoreap.conf", "image/systemd/99-wedge-autoreap.conf"),
]
with open("build/expected-injected.sha256", "w") as f:
    for rel, p in files:
        h = hashlib.sha256(open(p, "rb").read()).hexdigest()
        f.write("%s  %s\n" % (h, rel))
print("manifest regenerated:", len(files), "files")
PY
