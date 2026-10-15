#!/bin/bash
# K30 5G (picasso) Wi-Fi bringup — proven recipe 2026-10-15.
# Loads the SIGNED in-tree wlan.ko (CONFIG_QCA_CLD_WLAN=m) and triggers
# FW attach via the /dev/wlan control node.
#
# SAFETY (learned the hard way, see docs/08-wifi-bringup-tested.md):
#   * NEVER insmod while the Android container is still starting: the
#     cnss/icnss FW-attach race wedges the SoC silently (no logs, no panic).
#     -> wait until the container has been running >= MIN_AGE seconds.
#   * NEVER enable NM autoconnect on Wi-Fi profiles: autoconnect firing at
#     interface appearance races FW attach the same way.
set -u
LOG=/run/k30-wifi.log
exec >>"$LOG" 2>&1
echo "$(date -u +%T) k30-wifi-init start"

MIN_AGE=240
MOD=/lib/modules/"$(uname -r)"/updates/wlan.ko

# Already done (idempotent re-runs)
if [ -e /sys/class/net/wlan0 ] && lsmod | grep -q '^wlan '; then
    echo "$(date -u +%T) wlan already up"
    exit 0
fi

# 1. Wait for the Android container to be RUNNING
for i in $(seq 1 60); do
    lxc-info -n android 2>/dev/null | grep -q RUNNING && break
    sleep 2
done
if ! lxc-info -n android 2>/dev/null | grep -q RUNNING; then
    echo "$(date -u +%T) container not running"
    exit 1
fi

# 2. Settle gate: container must be MIN_AGE seconds old
CPID=$(lxc-info -n android -pH 2>/dev/null | head -1)
for i in $(seq 1 90); do
    age=$(ps -o etimes= -p "$CPID" 2>/dev/null | tr -d ' ')
    [ -n "$age" ] && [ "$age" -ge "$MIN_AGE" ] && break
    sleep 5
done
age=$(ps -o etimes= -p "$CPID" 2>/dev/null | tr -d ' ')
echo "$(date -u +%T) container age=${age:-unknown}s (minimum ${MIN_AGE}s)"

# 3. Load the driver (signed with the build-time kernel key)
if ! lsmod | grep -q '^wlan '; then
    if ! insmod "$MOD"; then
        echo "$(date -u +%T) insmod $MOD failed"
        exit 1
    fi
    echo "$(date -u +%T) wlan.ko loaded"
fi

# 4. Register /dev/wlan and trigger power/FW attach
MAJOR=""
for i in $(seq 1 30); do
    MAJOR=$(awk '$2=="qcwlanstate" || $2=="wlan" {print $1}' /proc/devices)
    [ -n "$MAJOR" ] && break
    sleep 1
done
if [ -z "$MAJOR" ]; then
    echo "$(date -u +%T) wlan character device not found in /proc/devices"
    exit 1
fi
rm -f /dev/wlan
mknod /dev/wlan c "$MAJOR" 0
chmod 660 /dev/wlan

for i in $(seq 1 24); do
    [ -e /sys/class/net/wlan0 ] && break
    echo ON > /dev/wlan 2>/dev/null || true
    sleep 5
done

if [ -e /sys/class/net/wlan0 ]; then
    ip link set wlan0 up 2>/dev/null || true
    echo "$(date -u +%T) wlan0 ready"
    exit 0
fi
echo "$(date -u +%T) wlan0 did not appear"
exit 1
