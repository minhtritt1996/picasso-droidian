#!/bin/bash
# K30 5G (picasso) CPU Power Clamping and Battery Brownout Prevention
# Prevents sudden PMIC PS_HOLD drops by capping peak CPU frequencies
# on Snapdragon 765G Kryo 475 Gold/Prime cores.

for cpu in cpu6 cpu7; do
    p="/sys/devices/system/cpu/$cpu/cpufreq/scaling_max_freq"
    if [ -w "$p" ]; then
        echo 1804800 > "$p" 2>/dev/null || true
    fi
done

for c in /sys/devices/system/cpu/cpu[0-7]/cpufreq/scaling_min_freq; do
    if [ -w "$c" ]; then
        echo 300000 > "$c" 2>/dev/null || true
    fi
done

exit 0
