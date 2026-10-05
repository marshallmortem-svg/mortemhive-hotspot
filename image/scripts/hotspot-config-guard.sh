#!/bin/bash
# hotspot-config-guard.sh — no transmit until configured.
# Runs once per boot (After the modem services): if the callsign is still the
# stock placeholder, stop MMDVMHost + DMRGateway so the radio cannot key up
# without a valid station identification. Configure via the Pi-Star dashboard.
CS=$(grep -E '^Callsign=' /etc/mmdvmhost 2>/dev/null | head -1 | cut -d= -f2 | tr -d '[:space:]')
if [ -z "$CS" ] || [ "$CS" = "N0CALL" ]; then
  logger -t hotspot-config-guard "callsign unconfigured (${CS:-none}) - stopping modem services (no transmit until configured)"
  systemctl stop mmdvmhost.service dmrgateway.service 2>/dev/null
fi
exit 0
