#!/bin/bash
# Picasso (Redmi K30 5G) Display & Backlight Hardware Power Initializer

send_panel_init() {
    # 1. Turn on DSI 1.8V IO and LCDB +/-5.5V Panel Bias Regulators
    echo 1 > /sys/kernel/debug/regulator/18200000.rsc:rpmh-regulator-ldoc1-pm8150a_l1/enable 2>/dev/null
    echo 1 > /sys/kernel/debug/regulator/c440000.qcom,spmi:qcom,pm8150l@5:qcom,lcdb@ec00-lcdb_ldo/enable 2>/dev/null
    echo 1 > /sys/kernel/debug/regulator/c440000.qcom,spmi:qcom,pm8150l@5:qcom,lcdb@ec00-lcdb_ncp/enable 2>/dev/null

    # 2. Configure LCDB module enable
    echo 0xec46 0x80 > /sys/kernel/debug/regmap/spmi0-05/registers 2>/dev/null

    # 3. Turn on Front White Indicator LED for visibility
    echo 255 > /sys/class/leds/white/brightness 2>/dev/null

    # 4. Set backlight brightness only if uninitialized or near-zero (default ~25%)
    CUR_B=$(cat /sys/class/backlight/backlight/brightness 2>/dev/null || echo 0)
    if [ -z "$CUR_B" ] || [ "$CUR_B" -le 100 ]; then
        echo 1024 > /sys/class/backlight/panel0-backlight/brightness 2>/dev/null
        echo 1024 > /sys/class/backlight/backlight/brightness 2>/dev/null
    fi

    # 5. Lock WLED5 hardware registers to direct register control (bypass CABC gate) without forcing max level
    echo 0xd951 0x00 > /sys/kernel/debug/regmap/spmi0-05/registers 2>/dev/null
    echo 0xd965 0x01 > /sys/kernel/debug/regmap/spmi0-05/registers 2>/dev/null
    echo 0xd965 0x00 > /sys/kernel/debug/regmap/spmi0-05/registers 2>/dev/null

    # 6. Initialize panel sleep out and display on
    if [ -w /sys/kernel/debug/dri/0/DSI-1/tx_cmd ]; then
        echo 0x05 0x01 0x00 0x00 0x46 0x00 0x01 0x11 > /sys/kernel/debug/dri/0/DSI-1/tx_cmd 2>/dev/null
        echo 0x05 0x01 0x00 0x00 0x00 0x00 0x01 0x29 > /sys/kernel/debug/dri/0/DSI-1/tx_cmd 2>/dev/null
        echo 0x15 0x01 0x00 0x00 0x00 0x00 0x02 0xFF 0x27 > /sys/kernel/debug/dri/0/DSI-1/tx_cmd 2>/dev/null
        echo 0x15 0x01 0x00 0x00 0x00 0x00 0x02 0xFB 0x01 > /sys/kernel/debug/dri/0/DSI-1/tx_cmd 2>/dev/null
        echo 0x15 0x01 0x00 0x00 0x00 0x00 0x02 0x3F 0x01 > /sys/kernel/debug/dri/0/DSI-1/tx_cmd 2>/dev/null
        echo 0x15 0x01 0x00 0x00 0x00 0x00 0x02 0x43 0x08 > /sys/kernel/debug/dri/0/DSI-1/tx_cmd 2>/dev/null
        echo 0x15 0x01 0x00 0x00 0x00 0x00 0x02 0x40 0x25 > /sys/kernel/debug/dri/0/DSI-1/tx_cmd 2>/dev/null
        echo 0x15 0x01 0x00 0x00 0x00 0x00 0x02 0xFF 0x10 > /sys/kernel/debug/dri/0/DSI-1/tx_cmd 2>/dev/null
        echo 0x39 0x01 0x00 0x00 0x00 0x00 0x03 0x51 0x0F 0xFF > /sys/kernel/debug/dri/0/DSI-1/tx_cmd 2>/dev/null
        echo 0x15 0x01 0x00 0x00 0x00 0x00 0x02 0x53 0x24 > /sys/kernel/debug/dri/0/DSI-1/tx_cmd 2>/dev/null
    fi

    # 7. Disable idle power collapse to prevent watchdog reboot
    echo 0 > /sys/devices/platform/soc/ae00000.qcom,mdss_mdp/idle_timeout_ms 2>/dev/null
    echo 0 > /sys/devices/platform/soc/ae00000.qcom,mdss_mdp/idle_encoder_mask 2>/dev/null
    echo N > /sys/kernel/debug/dri/0/encoder28/idle_power_collapse 2>/dev/null

    # 8. Disable PMIC charging hardware watchdog (prevent sudden reset / cold boot bite)
    echo '0x1651 0x00' > /sys/kernel/debug/regmap/spmi0-02/registers 2>/dev/null
    echo '0x1643 0x01' > /sys/kernel/debug/regmap/spmi0-02/registers 2>/dev/null

    # 9. Lock Xiaomi LCD hardware display parameters
    DISP_PARAM="/sys/devices/platform/soc/ae00000.qcom,mdss_mdp/drm/card0/card0-DSI-1/disp_param"
    if [ -e "$DISP_PARAM" ]; then
        chmod 0666 "$DISP_PARAM" 2>/dev/null || true
        echo "0x0B000000" > "$DISP_PARAM" 2>/dev/null || true
        echo "0x00000400" > "$DISP_PARAM" 2>/dev/null || true
        echo "0x0000F000" > "$DISP_PARAM" 2>/dev/null || true
        echo "0x50000000" > "$DISP_PARAM" 2>/dev/null || true
    fi
}

# Run immediate hardware setup
send_panel_init

# If DRM tx_cmd is not yet ready (early boot stage), wait asynchronously in background until DRM probes
if [ ! -w /sys/kernel/debug/dri/0/DSI-1/tx_cmd ]; then
    (
        for i in $(seq 1 60); do
            if [ -w /sys/kernel/debug/dri/0/DSI-1/tx_cmd ]; then
                sleep 0.5
                send_panel_init
                break
            fi
            sleep 0.5
        done
    ) &
fi
