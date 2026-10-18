#!/bin/bash
# Xiaomi Redmi K30 5G (picasso) - Backlight Persistence & Default Manager
STATE_FILE="/var/lib/k30-backlight.level"
MAX_B=4095
DEF_B=2048 # 50% default

save_brightness() {
    CUR=$(cat /sys/class/backlight/backlight/brightness 2>/dev/null || echo 0)
    if [ -n "$CUR" ] && [ "$CUR" -ge 100 ] && [ "$CUR" -le "$MAX_B" ]; then
        echo "$CUR" > "$STATE_FILE" 2>/dev/null || true
    fi
}

restore_brightness() {
    LEVEL=""
    if [ -f "$STATE_FILE" ]; then
        SAVED=$(cat "$STATE_FILE" 2>/dev/null || echo 0)
        if [ -n "$SAVED" ] && [ "$SAVED" -ge 100 ] && [ "$SAVED" -le "$MAX_B" ]; then
            LEVEL="$SAVED"
        fi
    fi
    if [ -z "$LEVEL" ]; then
        LEVEL="$DEF_B"
    fi
    echo "$LEVEL" > /sys/class/backlight/panel0-backlight/brightness 2>/dev/null || true
    echo "$LEVEL" > /sys/class/backlight/backlight/brightness 2>/dev/null || true
}

case "$1" in
    save)
        save_brightness
        ;;
    restore|*)
        restore_brightness
        ;;
esac
exit 0
