#!/bin/bash
# hotspot-display-assert.sh — MortemHive display assert.
#
# The MortemHive OLED dashboard (hotspot-oled.service) paints the panel
# directly, so MMDVMHost must keep its own display output OFF:
# [General] Display=None in /etc/mmdvmhost. Anything that rewrites that file
# — notably the Pi-Star dashboard's Display Type dropdown (applied via its
# web form) or a manual edit — would let MMDVMHost paint its stock screens
# over the custom dashboard.
#
# This runs as the FIRST ExecStartPre on mmdvmhost.service (installed by the
# 10-mortemhive-guard.conf drop-in), so Display=None is re-asserted BEFORE
# MMDVMHost reads its config, on every start. Best-effort by design: it never
# blocks the service start, and it logs what it did.
#
# Opt-out: if the custom dashboard service is disabled or masked, the admin
# has deliberately retired the custom screen — this script then does nothing
# and their display choice is left alone.
#
# Test hooks: MMDVM_CONF overrides the config path (fixtures).
MMDVM_CONF="${MMDVM_CONF:-/etc/mmdvmhost}"

[ -f "$MMDVM_CONF" ] || exit 0

# Respect a deliberate opt-out.
case "$(systemctl is-enabled hotspot-oled.service 2>/dev/null)" in
  disabled|masked) exit 0 ;;
esac

# Nothing to assert if the key is absent (MMDVMHost default) or already None.
grep -qE '^Display=' "$MMDVM_CONF" || exit 0
grep -qE '^Display=None[[:space:]]*$' "$MMDVM_CONF" && exit 0

# Rootfs is read-only by design: remount rw, edit, sync, restore prior state.
was_ro=0
mount 2>/dev/null | grep -E ' on / type ' | grep -q '(ro,' && was_ro=1
mount -o remount,rw / 2>/dev/null || true
sed -i 's/^Display=.*/Display=None/' "$MMDVM_CONF" 2>/dev/null || true
sync
if [ "$was_ro" = 1 ]; then
  mount -o remount,ro / 2>/dev/null || true
fi

if grep -qE '^Display=None[[:space:]]*$' "$MMDVM_CONF"; then
  logger -t hotspot-display-assert "MMDVMHost Display re-asserted to None (custom dashboard owns the panel)" 2>/dev/null || true
else
  logger -t hotspot-display-assert "WARN: could not re-assert Display=None (rootfs still read-only?)" 2>/dev/null || true
fi
exit 0
