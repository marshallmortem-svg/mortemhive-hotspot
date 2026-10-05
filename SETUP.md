# MortemHive Hotspot — First-Time Setup

**You do not need to know what SSH is to set this up.** Everything here can be done in a web
browser — from a phone or a computer — at http://pi-star.local (default login: pi-star /
raspberry — change it). Each step shows the browser way first. The SSH version is at the bottom
for helpers; it is never required.

The dashboard has three areas you will use:

- **Configuration** — the main settings form (callsign, DMR master, display).
- **Expert** — browser-based file editors, including "Quick Edit" forms for MMDVMHost and
  DMR GW. These do the hard parts for you: they handle the read-only system disk and restart
  the services after saving.
- **Front page** — live status; scroll down to see network logins and service states.

If you can log into your home router in a browser, you can do everything on this page.

## 1. First boot

Connect WiFi first (or join the "Pi-Star-Setup" access point ~2 minutes after power-up). The
first boot needs internet once to install the OLED software — several minutes on a Zero, and it
retries on every boot until it succeeds. A dark screen during that window is normal.

## 2. Callsign + DMR ID (browser)

1. Open http://pi-star.local and log in.
2. On the **Configuration** page, enter your **Callsign** and **DMR ID** (register at
   radioid.net if you have not — free, tied to your license).
3. Click **Apply Changes**.

The image has a built-in **no-transmit guard**: the modem refuses to start while the station
identity is still a placeholder, so nothing transmits until this step is done. While it is not
configured, the OLED shows "SET CALLSIGN + ID" — that is expected, not a fault.

Also on the Configuration page: the **Radio/Modem** dropdown ("What kind of radio or modem
hardware do you have?"). Pick the entry matching your board — the common Zero-size MMDVM_HS_Hat
boards are "MMDVM_HS_Hat (DB9MAT & DF2ET) for Pi (GPIO)". Leaving it blank (or wrong) can have
the dashboard rewrite the modem port settings when you apply.

## 3. BrandMeister (browser)

1. Register at brandmeister.network, then open SelfCare and set a **Hotspot Security** entry.
2. In the Pi-Star dashboard: **Configuration** page -> **DMR Master** dropdown -> choose
   "BrandMeister 3102 (United States)".
3. A security box appears — put your BrandMeister Hotspot Security value there.
4. Apply Changes.

Success check: the dashboard front page shows your network login status, and the OLED's bottom
line shows "NET✓" once things are up.

## 4. TGIF (browser, optional — it ships switched off)

1. Register at tgif.network and note your hotspot password from SelfCare.
2. In the dashboard, open **Expert** (top menu) -> under **Quick Edit** click **DMR GW**.
3. Find the section **[DMR Network 2]** and:
   - set **Enabled** to `1`,
   - put your TGIF hotspot password in the **Password** field,
   - leave address and port as they are (they are pre-filled; port 62031).
4. Click **Save**. The editor restarts the gateway for you.

On the radio, TGIF talkgroups are dialed in the 7-digit form: TGIF 3157 -> 4003157.

## 5. The OLED dashboard

You should see a splash with your callsign, then rotating screens — status (last heard /
talkgroup), Wi-Fi (dBm / SSID / IP), system (temp / uptime / load), and the mascot screen —
with a small two-dot "comet" circling the top-right corner of every screen. If the comet
freezes, the Pi is struggling; that is its job.

### What the screen can show (mini glossary)

- `SET CALLSIGN + ID` — the unit is not configured yet (see section 2); it clears by itself
  once both are real.
- `Listening…` — configured; the modem is idle and waiting for activity.
- `NET✓` / `NET✗` (bottom line) — internet reachability, checked every ~20 seconds.
- `no signal?` (Wi-Fi screen) — the Wi-Fi chip has not joined a network yet.
- `1NET✓` / `2NET✓` or just `-` (top badge) — how many DMR networks are logged in; `-` until
  the first login. It fills in when BrandMeister/TGIF connect.
- A frozen comet dot — the Pi is struggling; it should keep circling.
- The custom dashboard works fine while the unit is offline (it just says so); everything
  clears on its own once WiFi and the network logins are in place.

This one is self-healing: the image keeps MMDVMHost's own display switched off, and if that
setting ever gets flipped by accident it is corrected automatically at the next MMDVMHost
restart. If you still see the stock "MMDVMHost" screens instead of the custom dashboard, the
browser fix takes a minute:

1. **Configuration** page -> MMDVMHost section -> **Display Type** dropdown -> set it to
   **None** — yes, None, even though your hat has an OLED. This setting means "let MMDVMHost
   paint the screen", and the custom dashboard paints it instead.
2. Apply Changes.

Garbled or shifted screen? That is the wrong panel type for your hat: **Expert** -> Quick Edit
-> **MMDVMHost** -> `[OLED]` section -> **Type**: `3` (SSD1306) or `6` (SH1106) -> Save.

## 6. If something looks wrong — before asking for help

- **Look at the OLED.** It is your status display: NET✓ / NET✗ (internet), signal dBm, IP,
  temperature, uptime. A photo of the screen usually says it all.
- **The dashboard front page** shows whether the DMR networks are logged in; scroll down for
  the service states.
- **In the browser, no terminal needed:** Expert -> Quick Edit -> **DMR GW** to see your
  networks and their enabled state; the Configuration page for callsign / master / display.
- Getting help is much faster with: a photo of the OLED + what the front page shows.

## 7. A word about "Apply Changes"

The Configuration page writes the config files from whatever its form currently shows. After
ANY **Apply Changes**, it is worth glancing at these three (all in the browser):

1. Configuration -> MMDVMHost section: **Display Type** is still **None**.
2. Expert -> Quick Edit -> DMR GW: `[DMR Network 2]` still `Enabled=1` (if you use TGIF).
3. Expert -> Quick Edit -> MMDVMHost: `[General]` still shows your real **Callsign** and not
   a placeholder **Id**.

If any got reset, just set it back the same way and Save — that is all there is to it.

## 8. Over SSH (helpers only)

Everything above works in the browser; these blocks are for someone comfortable with a
terminal. SSH in as `pi-star` (default password `raspberry`), and remember the root filesystem
is read-only by design — remount around edits, as shown.

Fix the display setting (same as section 5, for scripts):

    sudo mount -o remount,rw /
    sudo sed -i 's/^Display=.*/Display=None/' /etc/mmdvmhost
    sudo sync; sudo mount -o remount,ro /
    sudo systemctl restart mmdvmhost hotspot-oled

Replace placeholder identity (same as section 2):

    sudo mount -o remount,rw /
    sudo sed -i 's/^Id=1234567/Id=YOUR_DMR_ID/' /etc/mmdvmhost /etc/dmrgateway
    sudo sed -i 's/^Callsign=N0CALL/Callsign=YOUR_CALL/' /etc/mmdvmhost
    sudo sync; sudo mount -o remount,ro /
    sudo systemctl restart mmdvmhost dmrgateway

Quick checks:

    systemctl is-active mmdvmhost dmrgateway hotspot-oled              # core services
    grep -n "^Callsign=\|^Id=" /etc/mmdvmhost /etc/dmrgateway         # identity lines
    grep "^Display=" /etc/mmdvmhost                                    # want: Display=None
    /usr/local/sbin/hotspot-config-guard.sh && echo CONFIGURED         # guard state
    journalctl -u hotspot-oled -b --no-pager | tail -20                # dashboard log
    grep "Logged into the master" /var/log/pi-star/DMRGateway-*.log    # network logins

Panel present on the I2C bus (hardware sanity):

    sudo i2cdetect -y 1        # the OLED answers at 0x3C

## 9. Quick reference

- Default login: `pi-star` / `raspberry` at http://pi-star.local — change it.
- The no-transmit guard holds the modem off until Callsign and DMR ID are real. By design.
- BrandMeister: Configuration -> DMR Master + security box. TGIF: Expert -> DMR GW ->
  `[DMR Network 2]`. Display: Configuration -> MMDVMHost -> Display Type = None.
- Root filesystem is read-only by default; the Expert editors and this guide's blocks handle
  that for you.

73 — see you on the air.
