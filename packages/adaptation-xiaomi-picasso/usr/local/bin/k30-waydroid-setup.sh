#!/bin/bash
# K30 5G Platform-Level Waydroid Hardware Integration & Safety Guard
set -e

echo "[+] Applying K30 5G platform-level Waydroid integration..."

# 1. Overlay directory setup
OVERLAY_SYS="/var/lib/waydroid/overlay_rw/system/system/etc/init"
OVERLAY_PERM="/var/lib/waydroid/overlay_rw/system/system/etc/permissions"
mkdir -p "$OVERLAY_SYS/hw" "$OVERLAY_PERM"

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

# 2. Patch LXC helper if present
LXC_PY="/usr/lib/waydroid/tools/helpers/lxc.py"
if [ -f "$LXC_PY" ]; then
    # Ensure sys/power nodes and sysrq are masked in lxc
    if ! grep -q "proc/sysrq-trigger" "$LXC_PY"; then
        sed -i '/make_entry("\/dev\/tty")/a \    make_entry("/dev/null", "proc/sysrq-trigger", options="bind,optional 0 0", check=False)\n    make_entry("/dev/null", "sys/power/state", options="bind,optional 0 0", check=False)\n    make_entry("/dev/null", "sys/power/wake_lock", options="bind,optional 0 0", check=False)\n    make_entry("/dev/null", "sys/power/wake_unlock", options="bind,optional 0 0", check=False)' "$LXC_PY"
    fi
    # Disable copying consumerir permissions
    sed -i 's/copy_list.append(.*consumerir.*)/# &/' "$LXC_PY" 2>/dev/null || true

    # Redirect lxc log to persistent /var/log/waydroid_lxc.log
    sed -i 's|/tmp/waydroid_lxc.log|/var/log/waydroid_lxc.log|g' "$LXC_PY" 2>/dev/null || true

    # Prevent cgroup v2 freezer crash on Linux 4.19 (no cgroup.freeze support)
    python3 -c "
with open('$LXC_PY', 'r') as f:
    c = f.read()
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
fi

echo "[✓] Waydroid platform integration applied successfully."
exit 0
