# MortemHive Hotspot v1.3

Flash-and-go Pi-Star SD image for **Raspberry Pi Zero W (v1.1) + MMDVM hat** (SSD1306 OLED).

## New in v1.3
- **Self-healing display** — MMDVMHost's own screen output is re-asserted to `None` before every
  MMDVMHost start, so the custom dashboard can never be covered by MMDVMHost's stock screens —
  not even by the Pi-Star dashboard's "Apply Changes". (Opt-out: disable the `hotspot-oled`
  service and the image leaves your display choice alone.)
- **Bulletproof first-boot installer** — found by our first community flasher and fixed the same
  day: the v1.2 installer could not install the OLED software (it assumed `pip3` existed and its
  pip invocation passed quoted arguments). It now installs `python3-pip` itself, uses clean bare
  package names, and still retries on every boot until the software is actually importable.
- **Browser-first setup guide (SETUP.md)** — every step now has a no-terminal path; the Pi-Star
  "Expert" Quick Edit editors handle the read-only disk and service restarts. SSH moved to a
  helper appendix; nobody needs to know what SSH is to get on the air.
- **Screen-state glossary** — every message the OLED can display is documented (`SET CALLSIGN + ID`,
  `NET✓/NET✗`, `no signal?`, the network badge), so users can read their own screen and send a
  photo instead of a puzzle.

## Carried from v1.2
- **Watchdog-proof no-transmit guard** — the modem refuses to start while the callsign or DMR ID
  is a stock placeholder, even against Pi-Star's own service watchdog.
- **Hardened PII audit**; TGIF ships disabled; BrandMeister needs your password; FM sample cleared.
- **Pinned deps**: luma.oled 3.16.0 / luma.core 2.6.0 / pillow 11.2.1 / smbus2 0.6.1 / RPi.GPIO 0.7.0.

## Base
- **Pi-Star 4.2.3 / kernel 5.10.103** — predates CVE-2026-31648, the kernel bug that makes current
  "latest" images lock up under load
- Custom OLED dashboard (status / wi-fi / system / mascot screens, inverted TX strip, liveness comet)
- Reliability shields armed (hardware watchdog + freeze-reaper)

**Flash:** Raspberry Pi Imager -> Use custom -> `MORTEMHIVE-Hotspot-v1.3.zip`
**Verify:** `MORTEMHIVE-Hotspot-v1.3.sha256` next to this release.
**First boot:** connect Wi-Fi first (or join Pi-Star-Setup), let the install finish (minutes),
then set your callsign + DMR ID at http://pi-star.local — until then the guard refuses to start
the modem.
