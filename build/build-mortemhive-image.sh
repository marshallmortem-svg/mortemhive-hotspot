#!/usr/bin/env bash
# ============================================================================
# build-mortemhive-image.sh — build the MortemHive Hotspot SD image.
# RUN ON A LINUX HOST (root) with:
#   /opt/pistar-image-build/mortemhive-kit/                    (this kit)
#   /opt/pistar-image-build/Pi-Star_RPi_V4.2.3_18-Apr-2025.zip (base)
# Output: /opt/pistar-image-build/MORTEMHIVE-Hotspot-v1.1.{img,zip,sha256}
# ============================================================================
set -euo pipefail
cd /opt/pistar-image-build
KIT=/opt/pistar-image-build/mortemhive-kit
WORK=$PWD/work
rm -rf "$WORK"; mkdir -p "$WORK"/{boot,root}

echo "== [1/9] unzip base (python3 — hosts may lack unzip) =="
python3 -m zipfile -e Pi-Star_RPi_V4.2.3_18-Apr-2025.zip "$WORK/"
IMG=$(find "$WORK" -maxdepth 1 -name "*.img" | head -1)
echo "base img: $IMG  ($(stat -c %s "$IMG") bytes)"

echo "== [2/9] loop mount =="
LOOP=$(losetup -Pf --show "$IMG")
trap 'umount "$WORK/root" 2>/dev/null; umount "$WORK/boot" 2>/dev/null; losetup -d "$LOOP" 2>/dev/null' EXIT
sleep 1
mount "${LOOP}p1" "$WORK/boot"
mount "${LOOP}p2" "$WORK/root"

echo "== [3/9] inject MortemHive files =="
install -m 644 "$KIT/image/configs/mmdvmhost"                    "$WORK/root/etc/mmdvmhost"
install -m 644 "$KIT/image/configs/dmrgateway"                   "$WORK/root/etc/dmrgateway"
install -m 644 "$KIT/image/configs/aprsgateway"                  "$WORK/root/etc/aprsgateway"
install -m 600 "$KIT/image/configs/wpa_supplicant.conf"          "$WORK/root/etc/wpa_supplicant/wpa_supplicant.conf"
install -m 755 "$KIT/image/scripts/hotspot-oled-dash.py"         "$WORK/root/usr/local/sbin/hotspot-oled-dash.py"
install -m 644 "$KIT/image/systemd/hotspot-oled.service"         "$WORK/root/etc/systemd/system/hotspot-oled.service"
install -m 755 "$KIT/image/scripts/hotspot-config-guard.sh"      "$WORK/root/usr/local/sbin/hotspot-config-guard.sh"
install -m 644 "$KIT/image/systemd/hotspot-config-guard.service" "$WORK/root/etc/systemd/system/hotspot-config-guard.service"
mkdir -p "$WORK/root/etc/systemd/system.conf.d" "$WORK/root/etc/sysctl.d"
install -m 644 "$KIT/image/systemd/watchdog.conf"                "$WORK/root/etc/systemd/system.conf.d/watchdog.conf"
install -m 644 "$KIT/image/systemd/99-wedge-autoreap.conf"       "$WORK/root/etc/sysctl.d/99-wedge-autoreap.conf"

echo "== [4/9] enable services + first-boot finisher =="
mkdir -p "$WORK/root/etc/systemd/system/multi-user.target.wants"
ln -sf /etc/systemd/system/hotspot-oled.service "$WORK/root/etc/systemd/system/multi-user.target.wants/hotspot-oled.service"
ln -sf /etc/systemd/system/hotspot-config-guard.service "$WORK/root/etc/systemd/system/multi-user.target.wants/hotspot-config-guard.service"

cat > "$WORK/root/usr/local/sbin/hotspot-finish-setup.sh" <<'FIN'
#!/bin/bash
# One-time first-boot finisher: install the OLED dashboard python deps
# (needs internet once). Safe to leave in place; it no-ops when satisfied.
if python3 -c "import luma.oled" 2>/dev/null; then exit 0; fi
systemctl stop hotspot-oled.service 2>/dev/null
mount -o remount,rw / 2>/dev/null
apt-get update -qq
apt-get install -y libopenjp2-7
pip3 install --default-timeout 100 "luma.oled==3.16.0" "luma.core==2.6.0" \
  || pip3 install --break-system-packages --default-timeout 100 "luma.oled==3.16.0" "luma.core==2.6.0"
sync; mount -o remount,ro / 2>/dev/null
systemctl restart hotspot-oled.service
systemctl disable hotspot-finish-setup.service 2>/dev/null
FIN
chmod 755 "$WORK/root/usr/local/sbin/hotspot-finish-setup.sh"
cat > "$WORK/root/etc/systemd/system/hotspot-finish-setup.service" <<'UNIT'
[Unit]
Description=MortemHive Hotspot first-boot finisher (OLED deps)
After=network-online.target
Wants=network-online.target
[Service]
Type=oneshot
ExecStart=/usr/local/sbin/hotspot-finish-setup.sh
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
UNIT
ln -sf /etc/systemd/system/hotspot-finish-setup.service "$WORK/root/etc/systemd/system/multi-user.target.wants/hotspot-finish-setup.service"

echo "== [5/9] verify injected files (sha256 manifest) =="
(cd "$WORK/root" && sha256sum -c "$KIT/build/expected-injected.sha256")

echo "== [6/9] boot-partition readme =="
cat > "$WORK/boot/MORTEMHIVE-README.txt" <<'NOTE'
MORTEMHIVE HOTSPOT v1.1 — flash-and-go Pi-Star image
Pi-Star 4.2.3 / kernel 5.10.103 — predates CVE-2026-31648, the kernel bug
that makes the current "latest" images lock up under load.

*** READ THIS FIRST ***
1. WiFi: connect the Pi to your network BEFORE (or immediately after) first
   boot — either drop a wpa_supplicant.conf on this boot volume before powering
   up, or join the "Pi-Star-Setup" access point ~2 minutes after boot from your
   phone. The first boot needs internet ONCE to install OLED support.
2. SET YOUR CALLSIGN + DMR ID at http://pi-star.local (pi-star / raspberry,
   change it!) — the transmitter REFUSES TO TRANSMIT until you do (a guard
   stops the modem services while the callsign is still N0CALL). Do not operate
   this unit on the air with placeholder identification.
3. The dependency install (pip, on a single-core Zero) can take several
   MINUTES on first boot. A dark screen during that window is expected — it
   retries and comes up. Patience, not panic.

What you get: custom OLED dashboard (status / wifi / system / mascot screens,
TX strip, liveness comet), hardware watchdog + freeze-reaper shields,
DMRGateway ready for BrandMeister + TGIF (enter your own passwords).
NOTE

echo "== [7/9] PII audit — LAST, over everything injected incl. boot =="
FILES=(
  "$WORK/root/etc/mmdvmhost" "$WORK/root/etc/dmrgateway" "$WORK/root/etc/aprsgateway"
  "$WORK/root/etc/wpa_supplicant/wpa_supplicant.conf"
  "$WORK/root/usr/local/sbin/hotspot-oled-dash.py" "$WORK/root/usr/local/sbin/hotspot-finish-setup.sh"
  "$WORK/root/usr/local/sbin/hotspot-config-guard.sh"
  "$WORK/root/etc/systemd/system/hotspot-oled.service" "$WORK/root/etc/systemd/system/hotspot-finish-setup.service"
  "$WORK/root/etc/systemd/system/hotspot-config-guard.service"
  "$WORK/root/etc/systemd/system.conf.d/watchdog.conf" "$WORK/root/etc/sysctl.d/99-wedge-autoreap.conf"
  "$WORK/boot/MORTEMHIVE-README.txt"
)
# content-scan exactly the files this kit installs (stock upstream files have
# public author credits that would false-positive); then sweep the WHOLE card
# for personal-looking file NAMES.
bash "$KIT/build/pii-audit.sh" "${FILES[@]}"
bash "$KIT/build/pii-audit.sh" --filename-only "$WORK/root" "$WORK/boot"

echo "== [8/9] unmount + repack =="
sync
umount "$WORK/root"; umount "$WORK/boot"; losetup -d "$LOOP"; trap - EXIT
mv "$IMG" MORTEMHIVE-Hotspot-v1.1.img
rm -rf "$WORK"
echo "repacking (level 1)..."
python3 - <<'PY'
import zipfile, os, time
name = "MORTEMHIVE-Hotspot-v1.1.img"
z = "MORTEMHIVE-Hotspot-v1.1.zip"
t0 = time.time()
with zipfile.ZipFile(z, "w", zipfile.ZIP_DEFLATED, compresslevel=1) as f:
    f.write(name)
print("zip done in %.0fs: %d bytes" % (time.time() - t0, os.path.getsize(z)))
PY

echo "== [9/9] hashes =="
sha256sum MORTEMHIVE-Hotspot-v1.1.img MORTEMHIVE-Hotspot-v1.1.zip > MORTEMHIVE-Hotspot-v1.1.sha256
cat MORTEMHIVE-Hotspot-v1.1.sha256
ls -lh MORTEMHIVE-Hotspot-v1.1.img MORTEMHIVE-Hotspot-v1.1.zip
echo "BUILD DONE"
