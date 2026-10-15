#!/bin/sh
while true; do
    echo '0x1651 0x00' > /sys/kernel/debug/regmap/spmi0-02/registers 2>/dev/null
    echo '0x1643 0x01' > /sys/kernel/debug/regmap/spmi0-02/registers 2>/dev/null
    sleep 5
done
