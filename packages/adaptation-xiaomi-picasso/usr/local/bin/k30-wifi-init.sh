#!/bin/bash
echo /vendor/firmware > /sys/module/firmware_class/parameters/path
modprobe wlan 2>/dev/null || insmod /lib/modules/$(uname -r)/kernel/drivers/staging/qcacld-3.0/wlan.ko 2>/dev/null || true

# Wait up to 60s for character device to register
for i in $(seq 1 60); do
    MAJOR=$(awk '$2=="qcwlanstate" || $2=="wlan" {print $1}' /proc/devices)
    if [ -n "$MAJOR" ]; then
        break
    fi
    sleep 1
done

if [ -z "$MAJOR" ]; then
    echo "wlan character device not found in /proc/devices"
    exit 1
fi

rm -f /dev/wlan
mknod /dev/wlan c "$MAJOR" 0
chmod 660 /dev/wlan

# Repeatedly request power ON until wlan0 interface is created
for i in $(seq 1 30); do
    if ip link show wlan0 >/dev/null 2>&1; then
        echo "wlan0 interface is up and ready!"
        break
    fi
    echo ON > /dev/wlan 2>/dev/null || true
    sleep 2
done

ip link set wlan0 up 2>/dev/null || true
exit 0
