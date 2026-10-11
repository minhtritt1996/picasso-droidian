#!/bin/sh
# Picasso WiFi bringup: container -> FW-ready -> settle -> vendor driver -> NM
# TESTED 2026-10-11/12. Two hard lessons baked in:
#  1. DO NOT insmod earlier: racing cnss-daemon init wedges the SoC (silent reset).
#     FW ready ~25-30s after lxc-start; insmod 30s after FW-ready (~60s total).
#  2. DO NOT enable NM autoconnect on wifi profiles (same reset at iface appearance).
LOG=/run/picasso-wifi.log
{
echo "$(date -u +%T) starting"
/usr/bin/lxc-info -n android 2>/dev/null | grep -q RUNNING || /usr/bin/lxc-start -d -n android
for i in $(seq 1 30); do
  dmesg | grep -q 'WLAN FW is ready' && break
  sleep 5
done
dmesg | grep -q 'WLAN FW is ready' || { echo "$(date -u +%T) FW never ready, abort"; exit 1; }
echo "$(date -u +%T) FW ready, settling 30s"
sleep 30
/usr/sbin/insmod /root/logkstub.ko 2>/dev/null
/usr/sbin/insmod /root/vmods/qca_cld3_wlan.ko 2>/dev/null || /usr/sbin/insmod /root/wlan_cld3_picasso.ko
sleep 8
if ls /sys/class/net/ | grep -q wlan0; then
  echo "$(date -u +%T) wlan0 up"
  /usr/bin/nmcli connection up 'TRUONG CUOM' ifname wlan0 2>/dev/null || true
else
  echo "$(date -u +%T) no wlan0!"
fi
} >> $LOG 2>&1
