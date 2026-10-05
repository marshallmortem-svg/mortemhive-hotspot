# Sanitization notes

This image and kit are built to ship clean, and the build enforces it:

- **`build/pii-audit.sh`** runs **inside every image build** (after all files,
  including the boot-partition README, are in place) and the build fails if it
  hits anything. It content-scans exactly the files this kit installs, then
  runs a filename sweep over the whole card for personal-looking names.
  (Base-image stock files are upstream content and are not re-audited.)
- The audit has two layers:
  1. **Generic patterns** (safe to publish): credential-looking lines
     (`psk=`/`Password=`/tokens), callsign shapes, decimal coordinate pairs,
     e-mail addresses — things that shouldn't appear in a clean kit at all.
  2. **A local strict deny-list** at `build/pii-audit.local` — one literal
     string per line — which is **gitignored and must never be committed**.
     It is the maintainer's private list of exact strings to catch, kept OUT of
     the repository precisely so the repo can't become the leak.

## What's stripped from the public kit

| Stripped | Replaced with |
|----------|---------------|
| Builder's callsign (mmdvmhost, aprsgateway, dashboard splash) | `N0CALL` (or read dynamically from config) |
| Builder's DMR IDs (mmdvmhost, dmrgateway ×3, dashboard override) | `1234567`; dashboard resolves the *configured* ID dynamically |
| APRS-IS passcode | empty (and APRS gateway ships disabled) |
| Saved WiFi networks + PSKs | none — clean `wpa_supplicant.conf` skeleton |
| BrandMeister / TGIF hotspot passwords | empty / `CHANGE_ME` (you supply yours) |
| Location (lat/long/town/description/QRZ URL) | `0.0` / `Your Town` / empty |
| Personal filenames | renamed to `hotspot-*` (audited by filename scan too) |

## No-transmit guard

`hotspot-config-guard.sh` (enabled by default) stops MMDVMHost + DMRGateway on
boot while the callsign is still `N0CALL`. The unit cannot transmit with
placeholder identification; it starts working the moment you configure a real
callsign in the dashboard and reboot/apply.

## History note (2026-10-05)

An earlier draft of this kit shipped an audit script that embedded the literal
deny-list — i.e. the audit file itself contained the personal strings it was
meant to find (and excluded itself from its own scan). It was caught in an
adversarial review, the audit was redesigned as described above, and the
repository was rebuilt from a clean history. **Never put literal secrets into a
scanner; keep deny-lists local and gitignored.**

## Base image provenance

- Base: `Pi-Star_RPi_V4.2.3_18-Apr-2025.zip` from <https://www.pistar.uk/downloads/>
  (the 4.3.7 "latest" branch is avoided on purpose — see README).
