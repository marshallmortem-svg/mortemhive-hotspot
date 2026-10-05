#!/bin/bash
# hotspot-config-guard.sh — MortemHive no-transmit guard.
#
# Checks that this hotspot has a real station identity configured:
#   exit 0 = configured  -> modem services may run
#   exit 1 = NOT configured -> refuse (used as an ExecStartPre on
#            mmdvmhost.service and dmrgateway.service via the drop-ins in
#            /etc/systemd/system/*.service.d/10-mortemhive-guard.conf)
#
# Because this runs as an ExecStartPre, the modem services REFUSE TO START
# while unconfigured. That holds even against Pi-Star's own pistar-watchdog,
# which restarts missing services but cannot bypass a failed pre-start check.
#
# --enforce : also stop the services if they are currently running while
#             unconfigured (belt-and-braces, used by the boot-time unit).
#
# Test hooks: MMDVM_CONF / DMRGW_CONF override the config paths (fixtures).
MMDVM_CONF="${MMDVM_CONF:-/etc/mmdvmhost}"
DMRGW_CONF="${DMRGW_CONF:-/etc/dmrgateway}"

refuse() {
  logger -t hotspot-config-guard "$1" 2>/dev/null || true
  echo "hotspot-config-guard: $1" >&2
}

cs=$(grep -m1 -E '^Callsign=' "$MMDVM_CONF" 2>/dev/null | cut -d= -f2 | tr -d '[:space:]"')
bad=0
reason=""

if [ -z "$cs" ]; then
  bad=1; reason="callsign not configured (empty)"
elif [ "$cs" = "N0CALL" ] || [ "$cs" = "MT1998" ]; then
  bad=1; reason="callsign still a stock placeholder ($cs)"
fi

if grep -qE '^Id=1234567([^0-9]|$)' "$MMDVM_CONF" "$DMRGW_CONF" 2>/dev/null; then
  bad=1; reason="${reason:+$reason; }DMR ID still the stock placeholder (1234567)"
fi

if [ "$bad" = 1 ]; then
  refuse "REFUSING modem start: $reason. Set Callsign + DMR ID in the Pi-Star dashboard (http://pi-star.local)."
  if [ "${1:-}" = "--enforce" ]; then
    systemctl stop mmdvmhost.service dmrgateway.service 2>/dev/null || true
  fi
  exit 1
fi
exit 0
