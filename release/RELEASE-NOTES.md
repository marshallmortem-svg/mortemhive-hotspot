# MortemHive Hotspot v1.2

Flash-and-go Pi-Star SD image for **Raspberry Pi Zero W (v1.1) + MMDVM hat** (SSD1306 OLED).

## New in v1.2
- **Watchdog-proof no-transmit guard** — the modem services now *refuse to start* while the callsign or DMR ID is still a stock placeholder (an ExecStartPre check). This holds even against Pi-Star's own pistar-watchdog, which cannot restart a service that refuses to start. (v1.1's stop-based guard could be undone by the stock watchdog — fixed.)
- **Audit hardening** — US-callsign shapes now cover 2x prefixes (the two-letter forms were previously missed); hotspot password fields and unquoted passphrases are covered; per-line coordinate detection; placeholder values excluded per value instead of per line; EOF-safe deny-list reading; fails closed on missing targets.
- **First-boot finisher now truly retries** — an offline first boot no longer disables the dependency installer; it retries on every boot until the OLED deps are importable.
- **TGIF ships disabled** by default (no surprise auto-join); BrandMeister requires your password as before; the `[FM]` sample callsign was cleared.
- **Deploy script**: rootfs always re-locked (even on failure), guard-aware service step, Wi-Fi config backups preserved.
- **Dependencies pinned**: luma.oled 3.16.0 / luma.core 2.6.0 / pillow 11.2.1 / smbus2 0.6.1 / RPi.GPIO 0.7.0.

## Base
- **Pi-Star 4.2.3 / kernel 5.10.103** — predates CVE-2026-31648, the kernel bug that makes current "latest" images lock up under load
- Custom OLED dashboard (status / wi-fi / system / mascot screens, inverted TX strip, liveness comet, "SET CALLSIGN + ID" until configured)
- Reliability shields armed (hardware watchdog + freeze-reaper)

**Flash:** Raspberry Pi Imager → Use custom → `MORTEMHIVE-Hotspot-v1.2.zip`
**Verify:** `MORTEMHIVE-Hotspot-v1.2.sha256` next to this release.
**First boot:** connect Wi-Fi first (or join Pi-Star-Setup), let the install finish (minutes), then set your callsign + DMR ID at http://pi-star.local — until then the guard refuses to start the modem.
