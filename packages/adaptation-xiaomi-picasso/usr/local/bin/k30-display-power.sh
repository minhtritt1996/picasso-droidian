#!/bin/bash
# 1. Turn on DSI 1.8V IO and LCDB +/-5.5V Panel Bias Regulators
echo 1 > /sys/kernel/debug/regulator/18200000.rsc:rpmh-regulator-ldoc1-pm8150a_l1/enable 2>/dev/null
echo 1 > /sys/kernel/debug/regulator/c440000.qcom,spmi:qcom,pm8150l@5:qcom,lcdb@ec00-lcdb_ldo/enable 2>/dev/null
echo 1 > /sys/kernel/debug/regulator/c440000.qcom,spmi:qcom,pm8150l@5:qcom,lcdb@ec00-lcdb_ncp/enable 2>/dev/null

# 2. Configure LCDB module enable
echo 0xec46 0x80 > /sys/kernel/debug/regmap/spmi0-05/registers 2>/dev/null

# 3. Turn on Front White Indicator LED for visibility
echo 255 > /sys/class/leds/white/brightness 2>/dev/null

# 4. Set backlight brightness to maximum (4095) in sysfs
echo 4095 > /sys/class/backlight/panel0-backlight/brightness 2>/dev/null
echo 4095 > /sys/class/backlight/backlight/brightness 2>/dev/null

# 5. Lock WLED5 hardware registers to direct register control (bypass CABC gate) at max brightness (4095)
echo 0xd951 0x00 > /sys/kernel/debug/regmap/spmi0-05/registers 2>/dev/null
echo 0xd953 0xff > /sys/kernel/debug/regmap/spmi0-05/registers 2>/dev/null
echo 0xd954 0x0f > /sys/kernel/debug/regmap/spmi0-05/registers 2>/dev/null
echo 0xd965 0x01 > /sys/kernel/debug/regmap/spmi0-05/registers 2>/dev/null
echo 0xd965 0x00 > /sys/kernel/debug/regmap/spmi0-05/registers 2>/dev/null

# 6. Initialize panel sleep out and display on if debugfs ready
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

# 9. Lock Xiaomi LCD hardware display parameters to eliminate screen flickering / jitter:
# - DISPPARAM_IDLE_OFF (0x0B000000): disable panel idle sleep
# - DISPPARAM_CABC_OFF (0x00000400): disable content-adaptive backlight flickering
# - DISPPARAM_ACL_OFF  (0x0000F000): disable auto-contrast luminance shifts
# - DISPPARAM_DFPS_LEVEL5 & Smart DFPS off (0x50000000): lock 120Hz & prevent 50Hz mode flapping
DISP_PARAM="/sys/devices/platform/soc/ae00000.qcom,mdss_mdp/drm/card0/card0-DSI-1/disp_param"
if [ -e "$DISP_PARAM" ]; then
    chmod 0666 "$DISP_PARAM" 2>/dev/null || true
    echo "0x0B000000" > "$DISP_PARAM" 2>/dev/null || true
    echo "0x00000400" > "$DISP_PARAM" 2>/dev/null || true
    echo "0x0000F000" > "$DISP_PARAM" 2>/dev/null || true
    echo "0x50000000" > "$DISP_PARAM" 2>/dev/null || true
fi

