#!/bin/bash
# K30 5G Platform-Level Waydroid Hardware Integration & Safety Guard
set -e

echo "[+] Applying K30 5G platform-level Waydroid integration..."

# 1. Overlay directory setup
OVERLAY_SYS="/var/lib/waydroid/overlay_rw/system/system/etc/init"
OVERLAY_PERM="/var/lib/waydroid/overlay_rw/system/system/etc/permissions"
OVERLAY_BIN="/var/lib/waydroid/overlay_rw/system/system/bin"
mkdir -p "$OVERLAY_SYS/hw" "$OVERLAY_PERM" "$OVERLAY_BIN"

# Mask missing Consumer IR HAL to prevent SystemServer crash loop
cat << 'EOF' > "$OVERLAY_PERM/android.hardware.consumerir.xml"
<permissions></permissions>
EOF

# Mask problematic Android 13 reboot-on-failure triggers
if [ -f "$OVERLAY_SYS/vold.rc" ]; then
    sed -i 's/^[[:space:]]*reboot_on_failure/# reboot_on_failure/' "$OVERLAY_SYS/vold.rc"
fi
if [ -f "$OVERLAY_SYS/apexd.rc" ]; then
    sed -i 's/^[[:space:]]*reboot_on_failure/# reboot_on_failure/' "$OVERLAY_SYS/apexd.rc"
fi

# Mask kernel crash vectors: wifi tracing, wificond scanning, llkd wdog bite
echo '# Disabled for waydroid' > "$OVERLAY_SYS/wifi.rc"
echo '# Disabled for waydroid' > "$OVERLAY_SYS/wificond.rc"
echo '# Disabled for waydroid' > "$OVERLAY_SYS/llkd.rc"

# Mask USB gadget triggers inside container to prevent PMIC hardware trip
echo '# Disabled for waydroid' > "$OVERLAY_SYS/hw/init.usb.rc"
echo '# Disabled for waydroid' > "$OVERLAY_SYS/hw/init.usb.configfs.rc"
echo '# Disabled for waydroid' > "$OVERLAY_SYS/usbd.rc"

# Install anti-sdcardfs patched vold binary
if [ -f /usr/lib/droidian/device/vold_patched ]; then
    cp -f /usr/lib/droidian/device/vold_patched "$OVERLAY_BIN/vold"
    chown 0:2000 "$OVERLAY_BIN/vold" 2>/dev/null || true
    chmod 755 "$OVERLAY_BIN/vold"
fi

# Bypass bpfloader in overlay to prevent incompatible eBPF kernel crashes
if [ -f "$OVERLAY_SYS/bpfloader.rc" ]; then
    sed -i 's/exec_start bpfloader/setprop bpf.progs_loaded 1/' "$OVERLAY_SYS/bpfloader.rc"
fi
cat << 'EOF' > "$OVERLAY_BIN/bpfloader"
#!/system/bin/sh
setprop bpf.progs_loaded 1
exit 0
EOF
chmod 755 "$OVERLAY_BIN/bpfloader"

# 2. Patch LXC helper if present
LXC_PY="/usr/lib/waydroid/tools/helpers/lxc.py"
if [ -f "$LXC_PY" ]; then
    # Ensure sys/power nodes, sysrq, tracing, and android_usb are masked in lxc
    python3 -c "
with open('$LXC_PY', 'r') as f:
    c = f.read()

# Mask dangerous nodes
if 'proc/sysrq-trigger' not in c:
    c = c.replace('make_entry(\"/dev/tty\")',
        'make_entry(\"/dev/tty\")\n    make_entry(\"/dev/null\", \"proc/sysrq-trigger\", options=\"bind,optional 0 0\", check=False)\n    make_entry(\"/dev/null\", \"sys/power/state\", options=\"bind,optional 0 0\", check=False)\n    make_entry(\"/dev/null\", \"sys/power/wake_lock\", options=\"bind,optional 0 0\", check=False)\n    make_entry(\"/dev/null\", \"sys/power/wake_unlock\", options=\"bind,optional 0 0\", check=False)')

if 'sys/kernel/tracing' not in c:
    c = c.replace('make_entry(\"tmpfs\", \"sys/kernel/debug\"',
        'make_entry(\"tmpfs\", \"sys/kernel/tracing\", \"tmpfs\", \"nosuid,nodev,noexec 0 0\", check=False)\n    make_entry(\"tmpfs\", \"sys/class/android_usb\", \"tmpfs\", \"nosuid,nodev,noexec 0 0\", check=False)\n    make_entry(\"tmpfs\", \"sys/class/power_supply\", \"tmpfs\", \"nosuid,nodev,noexec 0 0\", check=False)\n    make_entry(\"tmpfs\", \"sys/power\", \"tmpfs\", \"nosuid,nodev,noexec 0 0\", check=False)\n    make_entry(\"tmpfs\", \"sys/kernel/debug\"')
elif 'sys/class/power_supply' not in c:
    c = c.replace('make_entry(\"tmpfs\", \"sys/class/android_usb\"',
        'make_entry(\"tmpfs\", \"sys/class/android_usb\", \"tmpfs\", \"nosuid,nodev,noexec 0 0\", check=False)\n    make_entry(\"tmpfs\", \"sys/class/power_supply\", \"tmpfs\", \"nosuid,nodev,noexec 0 0\", check=False)\n    make_entry(\"tmpfs\", \"sys/power\", \"tmpfs\", \"nosuid,nodev,noexec 0 0\", check=False)')

# Ensure GPU acceleration nodes are passed
if 'make_entry(\"/dev/kgsl-3d0\")' not in c:
    c = c.replace('make_entry(\"/dev/fuse\")',
        'make_entry(\"/dev/fuse\")\n    make_entry(\"/dev/ion\")\n    make_entry(\"/dev/kgsl-3d0\")\n    make_entry(\"/dev/dri\", options=\"bind,create=dir,optional 0 0\", check=False)')

# Disable copying consumerir permissions
c = c.replace('copy_list.append(\"/vendor/etc/permissions/android.hardware.consumerir.xml\")', '# consumerir disabled')

# Redirect lxc log to persistent /var/log/waydroid_lxc.log
c = c.replace('/tmp/waydroid_lxc.log', '/var/log/waydroid_lxc.log')

# Prevent cgroup v2 freezer crash on Linux 4.19
if 'def freeze(args):' in c and 'lxc-freeze' in c:
    c = c.replace('def freeze(args):\n    command = [\"lxc-freeze\", \"-P\", tools.config.defaults[\"lxc\"], \"-n\", \"waydroid\"]\n    tools.helpers.run.user(args, command)', 'def freeze(args):\n    pass')
    c = c.replace('def unfreeze(args):\n    command = [\"lxc-unfreeze\", \"-P\",\n               tools.config.defaults[\"lxc\"], \"-n\", \"waydroid\"]\n    tools.helpers.run.user(args, command)', 'def unfreeze(args):\n    pass')

with open('$LXC_PY', 'w') as f:
    f.write(c)
" 2>/dev/null || true
fi

# 3. Apply LXC config adjustments for clean Android init execution
LXC_CFG="/var/lib/waydroid/lxc/waydroid/config"
if [ -f "$LXC_CFG" ]; then
    # Ensure mknod capability is kept so init can create kmsg_debug/urandom
    if ! grep -q "mknod" "$LXC_CFG"; then
        sed -i 's/^lxc.cap.keep = /lxc.cap.keep = mknod /' "$LXC_CFG"
    fi
    # Ensure valid LXC 5.x mount syntax
    sed -i 's/sys:ro:rslave/sys:ro/' "$LXC_CFG" 2>/dev/null || true
    # Ensure console path is none
    if ! grep -q "lxc.console.path" "$LXC_CFG"; then
        echo "lxc.console.path = none" >> "$LXC_CFG"
    fi
    # Allow GPU major devices (226 for DRM, 235 for KGSL Adreno 620)
    if ! grep -q "c 235:\* rwm" "$LXC_CFG"; then
        sed -i '/c 504:\* rwm/a lxc.cgroup2.devices.allow = c 226:* rwm\nlxc.cgroup2.devices.allow = c 235:* rwm' "$LXC_CFG" 2>/dev/null || true
    fi
fi
if [ -f /usr/lib/waydroid/data/configs/config_base ] && ! grep -q "c 235:\* rwm" /usr/lib/waydroid/data/configs/config_base; then
    sed -i '/c 504:\* rwm/a lxc.cgroup2.devices.allow = c 226:* rwm\nlxc.cgroup2.devices.allow = c 235:* rwm' /usr/lib/waydroid/data/configs/config_base 2>/dev/null || true
fi

# 4. Waydroid config and properties
if [ -f /var/lib/waydroid/waydroid.cfg ]; then
    python3 -c "
import configparser
cfg = configparser.ConfigParser()
cfg.read('/var/lib/waydroid/waydroid.cfg')
if 'waydroid' in cfg:
    cfg['waydroid']['auto_adb'] = 'False'
if 'properties' not in cfg:
    cfg['properties'] = {}
cfg['properties']['external_storage.sdcardfs.enabled'] = '0'
cfg['properties']['ro.sys.sdcardfs'] = 'false'
cfg['properties']['persist.sys.sdcardfs'] = 'force_off'
cfg['properties']['persist.sys.fuse'] = 'true'
cfg['properties']['ro.sys.fuse'] = 'true'
cfg['properties']['persist.sys.fflag.override.settings_fuse'] = 'true'
cfg['properties']['persist.sys.usb.config'] = 'none'
cfg['properties']['sys.usb.config'] = 'none'
cfg['properties']['ro.hardware.egl'] = 'adreno'
cfg['properties']['ro.hardware.gralloc'] = 'default'
cfg['properties']['persist.waydroid.multi_windows'] = 'true'
with open('/var/lib/waydroid/waydroid.cfg', 'w') as f:
    cfg.write(f)
" 2>/dev/null || true
fi

echo "[✓] Waydroid platform integration applied successfully."
exit 0
