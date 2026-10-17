#!/bin/bash
# K30 5G (picasso) Wi-Fi bringup + safe auto-connect — proven recipe 2026-10-15.
# Loads the SIGNED in-tree wlan.ko (CONFIG_QCA_CLD_WLAN=m) and triggers
# FW attach via the /dev/wlan control node.
#
# SAFETY (learned the hard way, see docs/08-wifi-bringup-tested.md):
#   * NEVER insmod while the Android container is still starting: the
#     cnss/icnss FW-attach race wedges the SoC silently (no logs, no panic).
#     -> wait until the container has been running >= MIN_AGE seconds.
#   * NEVER enable NM autoconnect on Wi-Fi profiles: autoconnect firing at
#     interface appearance races FW attach the same way.
#   * Auto-connect (v1.2.3): this script connects explicitly AFTER bring-up
#     is finished (wlan0 present + SETTLE delay), with soft retries. A failed
#     auto-connect never fails the unit nor the boot (exit 0 always).
set -u
LOG=/run/k30-wifi.log
exec >>"$LOG" 2>&1
echo "$(date -u +%T) k30-wifi-init start"

MIN_AGE=40
SETTLE=5
MOD=/lib/modules/"$(uname -r)"/updates/wlan.ko
CFG=/etc/default/k30-wifi

connected() {
    nmcli -t -f DEVICE,STATE device status 2>/dev/null | grep -q '^wlan0:connected'
}

autoconnect() {
    # NM autoconnect stays OFF on the profiles (boot race, see header).
    # We connect explicitly here, only when the interface is fully ready.
    local prof="" i

    if connected; then
        echo "$(date -u +%T) wlan0 already connected"
        return 0
    fi

    # Profile selection: WIFI_PROFILE from $CFG, else the profile with the
    # highest connection.autoconnect-priority, else the first Wi-Fi profile.
    # shellcheck disable=SC1090
    [ -r "$CFG" ] && . "$CFG"
    if [ -n "${WIFI_PROFILE:-}" ]; then
        prof="$WIFI_PROFILE"
    else
        prof=$(nmcli -t -f NAME,TYPE,AUTOCONNECT-PRIORITY connection show 2>/dev/null \
            | awk -F: '$2=="802-11-wireless" {print $3 ":" $1}' \
            | sort -t: -k1,1nr -k2,2 | head -1 | cut -d: -f2-)
    fi

    if [ -z "$prof" ]; then
        echo "$(date -u +%T) no Wi-Fi profile found, skip auto-connect"
        return 0
    fi

    for i in 1 2 3 4 5; do
        connected && break
        echo "$(date -u +%T) connecting to '$prof' (attempt $i)"
        if timeout 60 nmcli connection up "$prof" ifname wlan0; then
            echo "$(date -u +%T) connected: $prof"
            return 0
        fi
        echo "$(date -u +%T) attempt $i failed (see NM log); retry in 15s"
        sleep 15
    done

    if connected; then
        echo "$(date -u +%T) connected: $prof"
    else
        echo "$(date -u +%T) auto-connect failed after 5 attempts (not blocking boot)"
    fi
    return 0
}

# Already brought up? (idempotent re-runs) -> go straight to auto-connect
if [ -e /sys/class/net/wlan0 ] && lsmod | grep -q '^wlan '; then
    echo "$(date -u +%T) wlan already up"
    autoconnect
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
for i in $(seq 1 60); do
    CPID=$(lxc-info -n android -pH 2>/dev/null | head -1)
    if [ -n "$CPID" ]; then
        age=$(ps -o etimes= -p "$CPID" 2>/dev/null | tr -d ' ')
        [ -n "$age" ] && [ "$age" -ge "$MIN_AGE" ] && break
    fi
    sleep 2
done
age=$(ps -o etimes= -p "${CPID:-0}" 2>/dev/null | tr -d ' ')
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

if [ ! -e /sys/class/net/wlan0 ]; then
    echo "$(date -u +%T) wlan0 did not appear"
    exit 1
fi
ip link set wlan0 up 2>/dev/null || true
echo "$(date -u +%T) wlan0 ready"

# 5. Let the FW attach / link layer fully settle before associating
sleep "$SETTLE"

# 6. Safe auto-connect (soft-fail, never blocks the boot)
autoconnect
exit 0
