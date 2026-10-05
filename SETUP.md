# MortemHive Hotspot — First-Time Setup

You flashed the image. Here is everything else — callsign, BrandMeister, TGIF, and getting the
OLED dashboard working the way it looks in the screenshots.

## Before you start

- Your **callsign** and **DMR ID** (register at radioid.net if you have not — free, tied to your license).
- A **BrandMeister** account (brandmeister.network) with a **Hotspot Security password** set in SelfCare.
- A **TGIF** account (tgif.network) with your account's hotspot password (16 characters, shown in SelfCare).

## 1. First boot

Connect WiFi first (or join the Pi-Star-Setup access point ~2 minutes after power-up). The first boot
needs internet once to install the OLED software — several minutes on a Zero, and it retries on every
boot until it succeeds. A dark screen during that window is normal.

## 2. Callsign + DMR ID

Open http://pi-star.local (default login pi-star / raspberry — change it), set your Callsign and DMR
ID, and Apply.

**The no-transmit guard:** the modem refuses to start while a placeholder identity remains. After
setting your callsign/ID, verify nothing placeholder is left anywhere:

    grep -n "^Callsign=\|^Id=" /etc/mmdvmhost /etc/dmrgateway

Every `Id=` must be your DMR ID (there are several, including in sections you may not use) and the
callsign must be your call. If any `Id=1234567` remains (SSH; the root filesystem is read-only by
default):

    sudo mount -o remount,rw /
    sudo sed -i 's/^Id=1234567/Id=YOUR_DMR_ID/' /etc/mmdvmhost /etc/dmrgateway    # replace YOUR_DMR_ID
    sudo sed -i 's/^Callsign=N0CALL/Callsign=YOUR_CALL/' /etc/mmdvmhost           # replace YOUR_CALL
    sudo sync; sudo mount -o remount,ro /
    sudo systemctl restart mmdvmhost dmrgateway

The unit starts transmitting only when the callsign AND every ID are real.

## 3. BrandMeister

In the Pi-Star dashboard (Configuration → DMR Gateway), enter your BrandMeister **Hotspot Security
password** for the BrandMeister network and select master **3102 (United States)**. If your dashboard
build lacks the field, edit the file:

    sudo mount -o remount,rw /
    sudo nano /etc/dmrgateway

In `[DMR Network 1]`, set the password entry to your BrandMeister Hotspot Security password
(the shipped placeholder fails closed until you do). Save; remount ro; restart. Success text:

    grep "Logged into the master" /var/log/pi-star/DMRGateway-*.log | tail

## 4. TGIF

TGIF ships **disabled** (opt-in). Register at tgif.network, copy your hotspot password from SelfCare:

    sudo mount -o remount,rw /
    sudo nano /etc/dmrgateway

In `[DMR Network 2]`: `Enabled=1`, set the password entry to your TGIF hotspot password, and
confirm `Port=62031` (a wrong port here silently retry-loops). Save; remount ro; restart. On the RADIO, TGIF talkgroups are dialed
in the 7-digit form: TGIF 3157 = `4003157`. Password wrong = `Login to the master has failed`; no
response at all = wrong address/port.

Both networks up = the OLED badge shows `2NET✓`.

## 5. The OLED dashboard

You should see a splash with your callsign, then rotating screens — status (last heard / talkgroup),
Wi-Fi (dBm/SSID/IP), system (temp/uptime/load), and the mascot screen — with a small two-dot "comet"
circling the top-right corner of every screen (a frozen comet means the Pi is struggling; that is its job).

The dashboard is its own service and needs the OLED software installed by the first-boot installer:

    systemctl status hotspot-oled --no-pager
    journalctl -u hotspot-oled -b --no-pager | tail -20
    python3 -c "import luma.oled; print('OLED deps OK')"

- **Deps missing** ("OLED deps OK" fails): give it internet and run
  `sudo systemctl restart hotspot-finish-setup.service`, or just reboot — the installer retries each boot.
- **Stock MMDVMHost text screens instead of the dashboard:** MMDVMHost's own display output must be
  OFF. Check `grep "^Display=" /etc/mmdvmhost` — it must be `Display=None`:

      sudo mount -o remount,rw /
      sudo sed -i 's/^Display=.*/Display=None/' /etc/mmdvmhost
      sudo sync; sudo mount -o remount,ro /
      sudo systemctl restart mmdvmhost hotspot-oled

- **Garbled / shifted columns:** wrong panel type for your hat. `[OLED] Type=3` is SSD1306; try `Type=6`
  (SH1106) or back:

      sudo mount -o remount,rw / && sudo sed -i 's/^Type=3/Type=6/' /etc/mmdvmhost && sudo sync && sudo mount -o remount,ro / && sudo systemctl restart hotspot-oled

- **Screen says "SET CALLSIGN + ID":** working as designed — it clears once callsign and DMR ID are set
  (section 2).
- **Blank screen:** usually the deps case above, or the panel type.

## 6. The Pi-Star "Apply Changes" trap — read this once

Pi-Star's dashboard rewrites `/etc/mmdvmhost` and `/etc/dmrgateway` from whatever its web forms
currently show. After ANY "Apply Changes", verify these survived:

    grep "^Display=" /etc/mmdvmhost                                # want: Display=None
    sed -n '/\[DMR Network 2\]/,/^$/p' /etc/dmrgateway | grep "^Enabled="   # want: Enabled=1 if you use TGIF
    grep -c "^Id=1234567" /etc/mmdvmhost /etc/dmrgateway           # want: 0 in both

If any got reset, re-apply the matching fix from section 5 (Display), section 4 (TGIF), or section 2
(IDs), then restart the services.

## 7. Quick reference

    systemctl is-active mmdvmhost dmrgateway hotspot-oled            # core services
    grep "Logged into the master" /var/log/pi-star/DMRGateway-*.log  # network logins
    /usr/local/sbin/hotspot-config-guard.sh && echo CONFIGURED       # guard state
    journalctl -u hotspot-oled -b | tail                             # dashboard log

Root filesystem: remount `rw` before edits, `ro` after (see above).

73 — see you on the air.
