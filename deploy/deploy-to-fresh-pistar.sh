#!/usr/bin/env bash
# ============================================================================
# deploy-to-fresh-pistar.sh — install the MortemHive Hotspot layer onto a
# freshly flashed Pi-Star (4.2.3) so a unit built from stock gets the custom
# dashboard + reliability shields without re-flashing the whole image.
# Usage:   ./deploy-to-fresh-pistar.sh <pi-ip-or-hostname> [ssh-password]
# Uses the stock Pi-Star login (user pi-star, image default) unless a
# password is given as the second argument.
# ============================================================================
set -euo pipefail
TARGET="${1:?usage: $0 <pi-ip> [ssh-password]}"
PW="${2:-raspberry}"
H="pi-star@${TARGET}"
KIT="$(cd "$(dirname "$0")/.." && pwd)"

SSH="sshpass -p ${PW} ssh -o ConnectTimeout=15 -o StrictHostKeyChecking=accept-new ${H}"
SCP="sshpass -p ${PW} scp -o ConnectTimeout=15 -o StrictHostKeyChecking=accept-new"
step() { echo; echo "== $1 =="; }

# always relock the rootfs, even if a later step fails
relock() { $SSH 'sudo mount -o remount,ro / 2>/dev/null' >/dev/null 2>&1 || true; }
trap relock EXIT

step "1/8 connectivity"
$SSH 'echo connected: $(hostname) $(uname -r)' || { echo "FAILED — check IP/password/network"; exit 1; }

step "2/8 remount rootfs read-write"
$SSH 'sudo mount -o remount,rw /'

step "3/8 upload files"
$SCP "${KIT}/image/configs/mmdvmhost"                "${H}:/tmp/mmdvmhost"
$SCP "${KIT}/image/configs/dmrgateway"               "${H}:/tmp/dmrgateway"
$SCP "${KIT}/image/configs/aprsgateway"              "${H}:/tmp/aprsgateway"
$SCP "${KIT}/image/configs/wpa_supplicant.conf"      "${H}:/tmp/wpa_supplicant.conf"
$SCP "${KIT}/image/scripts/hotspot-oled-dash.py"     "${H}:/tmp/hotspot-oled-dash.py"
$SCP "${KIT}/image/scripts/hotspot-config-guard.sh"  "${H}:/tmp/hotspot-config-guard.sh"
$SCP "${KIT}/image/systemd/hotspot-oled.service"     "${H}:/tmp/hotspot-oled.service"
$SCP "${KIT}/image/systemd/hotspot-config-guard.service" "${H}:/tmp/hotspot-config-guard.service"
$SCP "${KIT}/image/systemd/watchdog.conf"            "${H}:/tmp/watchdog.conf"
$SCP "${KIT}/image/systemd/99-wedge-autoreap.conf"   "${H}:/tmp/99-wedge-autoreap.conf"
$SCP "${KIT}/image/systemd/mmdvmhost-guard.conf"     "${H}:/tmp/mmdvmhost-guard.conf"
$SCP "${KIT}/image/systemd/dmrgateway-guard.conf"    "${H}:/tmp/dmrgateway-guard.conf"

step "4/8 install files (existing WiFi config is backed up, never clobbered)"
$SSH 'bash -s' <<'REMOTE'
set -e
sudo cp /tmp/mmdvmhost /etc/mmdvmhost
sudo cp /tmp/dmrgateway /etc/dmrgateway
sudo cp /tmp/aprsgateway /etc/aprsgateway
if sudo grep -q '^network=' /etc/wpa_supplicant/wpa_supplicant.conf 2>/dev/null; then
  echo "existing WiFi networks present -> backing up, NOT overwriting (keeps this unit online)"
  sudo cp /etc/wpa_supplicant/wpa_supplicant.conf "/etc/wpa_supplicant/wpa_supplicant.conf.bak.$(date +%s)"
else
  sudo cp /tmp/wpa_supplicant.conf /etc/wpa_supplicant/wpa_supplicant.conf
fi
sudo chmod 600 /etc/wpa_supplicant/wpa_supplicant.conf
sudo cp /tmp/hotspot-oled-dash.py /usr/local/sbin/hotspot-oled-dash.py
sudo cp /tmp/hotspot-config-guard.sh /usr/local/sbin/hotspot-config-guard.sh
sudo chmod 755 /usr/local/sbin/hotspot-oled-dash.py /usr/local/sbin/hotspot-config-guard.sh
sudo cp /tmp/hotspot-oled.service /etc/systemd/system/hotspot-oled.service
sudo cp /tmp/hotspot-config-guard.service /etc/systemd/system/hotspot-config-guard.service
sudo mkdir -p /etc/systemd/system.conf.d /etc/sysctl.d
sudo cp /tmp/watchdog.conf /etc/systemd/system.conf.d/watchdog.conf
sudo cp /tmp/99-wedge-autoreap.conf /etc/sysctl.d/99-wedge-autoreap.conf
sudo mkdir -p /etc/systemd/system/mmdvmhost.service.d /etc/systemd/system/dmrgateway.service.d
sudo cp /tmp/mmdvmhost-guard.conf /etc/systemd/system/mmdvmhost.service.d/10-mortemhive-guard.conf
sudo cp /tmp/dmrgateway-guard.conf /etc/systemd/system/dmrgateway.service.d/10-mortemhive-guard.conf
sudo systemctl enable hotspot-oled.service hotspot-config-guard.service
echo "install stage ok"
REMOTE

step "5/8 dependencies (needs internet; slow on a Zero — a few minutes)"
$SSH 'sudo apt-get update -qq && sudo apt-get install -y libopenjp2-7'
$SSH 'sudo pip3 install --default-timeout 100 "luma.oled==3.16.0" "luma.core==2.6.0" "pillow==11.2.1" "smbus2==0.6.1" "RPi.GPIO==0.7.0"'   || $SSH 'sudo pip3 install --break-system-packages --default-timeout 100 "luma.oled==3.16.0" "luma.core==2.6.0" "pillow==11.2.1" "smbus2==0.6.1" "RPi.GPIO==0.7.0"'

step "6/8 apply system config (guard-aware: modem runs only when configured)"
$SSH 'sudo systemctl daemon-reload; sudo systemctl daemon-reexec; sudo sysctl --system >/dev/null 2>&1; echo sysctl-ok'
$SSH 'if sudo /usr/local/sbin/hotspot-config-guard.sh; then echo "station configured -> modem services may run"; else sudo systemctl stop mmdvmhost dmrgateway 2>/dev/null || true; echo "NOT CONFIGURED yet -> modem services held off (guard). Set Callsign + DMR ID in the dashboard."; fi'
$SSH 'sudo systemctl restart hotspot-oled; sleep 5; systemctl is-active hotspot-oled || true'

step "7/8 relock rootfs read-only"
$SSH 'sudo sync; sudo mount -o remount,ro / && echo RO-OK'

step "8/8 next steps"
cat <<'NOTE'
  * Reboot to apply everything:  ssh pi-star@<ip> 'sudo reboot'
  * Then set your callsign + DMR ID at http://pi-star.local (dashboard).
    Until you do, the guard refuses to start the modem services — by design
    (it survives Pi-Star's own service watchdog).
  * Watch the OLED: splash -> dashboard with the liveness comet.
  * If the screen stays dark: journalctl -u hotspot-oled -b | tail
NOTE
echo "DONE."
