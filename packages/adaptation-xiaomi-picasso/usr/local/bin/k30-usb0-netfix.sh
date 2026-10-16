#!/bin/bash
# K30 5G (picasso): fix usb0 netmask /8 -> /24.
#
# /usr/bin/usb-tethering (package hybris-usb) runs `ifconfig usb0 10.15.19.82`
# WITHOUT a netmask (line 142), so classful ifconfig assigns 255.0.0.0 (/8).
# The resulting route "10.0.0.0/8 dev usb0" swallows every 10.x network,
# including the home LAN (e.g. 10.14.0.0/16): replies to LAN clients leave
# through usb0 and die -> SSH/ping to the phone over Wi-Fi stalls.
#
# This script re-asserts 10.15.19.82/24 on usb0. It is invoked:
#   - immediately by the package postinst (timeout-capped), and
#   - at every boot by a drop-in on usb-tethering.service (ExecStartPost).
# It never fails: exit 0 in all paths (must not break any unit or boot).
set -u
IFACE=usb0
IP=10.15.19.82

for _ in $(seq 1 20); do
    state=$(ip -br addr show "$IFACE" 2>/dev/null || true)
    case "$state" in
        *"${IP}/24"*) exit 0 ;;                     # already correct
        *"${IP}/8"*)
            ip addr del "${IP}/8" dev "$IFACE" 2>/dev/null || true
            ip addr add "${IP}/24" dev "$IFACE" 2>/dev/null || true
            logger -t k30-usb0-netfix "usb0: ${IP} /8 -> /24 (fixed)"
            exit 0
            ;;
    esac
    sleep 2
done

logger -t k30-usb0-netfix "usb0 ${IP} not seen after 40s; nothing to fix"
exit 0
