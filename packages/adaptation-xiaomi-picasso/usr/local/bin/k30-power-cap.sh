#!/bin/bash
# K30 5G (picasso) CPU Power Clamping and Battery Brownout Prevention
cap=$(cat /sys/class/power_supply/battery/capacity 2>/dev/null || echo 50)
if [ "$cap" -lt 30 ]; then
    # Low battery protection: conservative frequencies to prevent UVLO brownout
    for c in /sys/devices/system/cpu/cpu[0-5]/cpufreq/scaling_max_freq; do
        [ -w "$c" ] && echo 1363200 > "$c" 2>/dev/null || true
    done
    [ -w /sys/devices/system/cpu/cpu6/cpufreq/scaling_max_freq ] && echo 1094400 > /sys/devices/system/cpu/cpu6/cpufreq/scaling_max_freq 2>/dev/null || true
    [ -w /sys/devices/system/cpu/cpu7/cpufreq/scaling_max_freq ] && echo 1094400 > /sys/devices/system/cpu/cpu7/cpufreq/scaling_max_freq 2>/dev/null || true
else
    for c in /sys/devices/system/cpu/cpu[0-5]/cpufreq/scaling_max_freq; do
        [ -w "$c" ] && echo 1516800 > "$c" 2>/dev/null || true
    done
    [ -w /sys/devices/system/cpu/cpu6/cpufreq/scaling_max_freq ] && echo 1478400 > /sys/devices/system/cpu/cpu6/cpufreq/scaling_max_freq 2>/dev/null || true
    [ -w /sys/devices/system/cpu/cpu7/cpufreq/scaling_max_freq ] && echo 1401600 > /sys/devices/system/cpu/cpu7/cpufreq/scaling_max_freq 2>/dev/null || true
fi
exit 0
