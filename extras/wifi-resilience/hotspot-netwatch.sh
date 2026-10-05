#!/bin/bash
# hotspot-netwatch.sh — OPTIONAL extra: catches the "silent WiFi death" class the
# hardware watchdog cannot see (association alive-but-dead, stuck supplicant).
# Gentle recovery first, reboot as last resort. Never reboots just because the
# unit is out of range of every known network.
ST=/run/hotspot-netwatch.count
HAD=/run/hotspot-netwatch.hadnet
GW=$(ip route show default 2>/dev/null | awk '{print $3; exit}')
STATE=$(wpa_cli -i wlan0 status 2>/dev/null | awk -F= '/^wpa_state=/{print $2}')
n=$(cat "$ST" 2>/dev/null || echo 0)

if [ -n "$GW" ] && ping -c 2 -W 3 "$GW" >/dev/null 2>&1; then
  [ "$n" != "0" ] && logger -t hotspot-netwatch "network OK again (was failing x$n)"
  echo 0 > "$ST"
  touch "$HAD"
  exit 0
fi

if [ "$STATE" != "COMPLETED" ]; then
  if [ -f "$HAD" ] && [ "$n" -ge 15 ]; then
    logger -t hotspot-netwatch "no association ~15 min despite prior connection — one reassociate"
    wpa_cli -i wlan0 reassociate >/dev/null 2>&1
    echo 0 > "$ST"
  else
    n=$((n + 1)); echo "$n" > "$ST"
  fi
  exit 0
fi

n=$((n + 1)); echo "$n" > "$ST"
logger -t hotspot-netwatch "associated but gateway unreachable (x$n)"
if [ "$n" -eq 3 ]; then
  wpa_cli -i wlan0 reassociate >/dev/null 2>&1
  logger -t hotspot-netwatch "action: wpa_cli reassociate"
elif [ "$n" -eq 6 ]; then
  systemctl restart wpa_supplicant >/dev/null 2>&1 || wpa_cli -i wlan0 reconfigure >/dev/null 2>&1
  logger -t hotspot-netwatch "action: restart wpa_supplicant"
elif [ "$n" -ge 9 ] && [ -f "$HAD" ]; then
  logger -t hotspot-netwatch "network stuck ~9 min (had connectivity this boot) — REBOOTING as last resort"
  rm -f "$HAD"   # disarm: after the reboot, require a fresh healthy period
  sync
  reboot
elif [ "$n" -ge 15 ]; then
  logger -t hotspot-netwatch "still stuck at x$n with no prior connection — supplicant bounce (no reboot loop)"
  wpa_cli -i wlan0 reassociate >/dev/null 2>&1
  n=6; echo "$n" > "$ST"
fi
exit 0
