#!/bin/bash
# K30 5G Platform-Level Waydroid Hardware Integration & Safety Guard
set -e

echo "[+] Applying K30 5G platform-level Waydroid integration..."

# 1. Overlay directory setup
OVERLAY_SYS="/var/lib/waydroid/overlay_rw/system/system/etc/init"
OVERLAY_PERM="/var/lib/waydroid/overlay_rw/system/system/etc/permissions"
OVERLAY_BIN="/var/lib/waydroid/overlay_rw/system/system/bin"
mkdir -p "$OVERLAY_SYS/hw" "$OVERLAY_PERM" "$OVERLAY_BIN"

# Provide Consumer IR feature permission so ConsumerIrService does not crash SystemServer
cat << 'EOF' > "$OVERLAY_PERM/android.hardware.consumerir.xml"
<?xml version="1.0" encoding="utf-8"?>
<permissions>
    <feature name="android.hardware.consumerir" />
</permissions>
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

# Mask Qualcomm hardware scripts to prevent modem/venus subsystem restarts (SSR) inside container
OVERLAY_VENDOR_HW="/var/lib/waydroid/overlay_rw/vendor/etc/init/hw"
OVERLAY_VENDOR_INIT="/var/lib/waydroid/overlay_rw/vendor/etc/init"
mkdir -p "$OVERLAY_VENDOR_HW" "$OVERLAY_VENDOR_INIT"
for f in init.qcom.rc init.qcom.usb.rc init.qcom.factory.rc init.target.rc; do
    echo '# Disabled for waydroid' > "$OVERLAY_VENDOR_HW/$f"
done
# Mask camera provider which triggers power/LDO conflict with host Halium
echo '# Disabled for waydroid' > "$OVERLAY_VENDOR_INIT/android.hardware.camera.provider@2.4-service.rc"
# Ensure OMX and Codec2 hardware video services remain active for VPU acceleration
[ -f "$OVERLAY_VENDOR_INIT/android.hardware.media.omx@1.0-service.rc" ] && rm -f "$OVERLAY_VENDOR_INIT/android.hardware.media.omx@1.0-service.rc"
# Ensure Android STREAM_MUSIC volume defaults to 15 (max) on boot
cat << 'EOF' > "$OVERLAY_VENDOR_INIT/waydroid_audio.rc"
service waydroid_audio_init /system/bin/cmd media_session volume --stream 3 --set 15
    user system
    group system
    oneshot
    disabled

on property:sys.boot_completed=1
    start waydroid_audio_init
EOF
chmod 644 "$OVERLAY_VENDOR_INIT/waydroid_audio.rc"

if [ -f "$OVERLAY_SYS/hw/init.rc" ]; then
    sed -i 's|^[[:space:]]*import /vendor/etc/init/hw/init\.\${ro\.hardware}\.rc|# import /vendor/etc/init/hw/init.\${ro.hardware}.rc|' "$OVERLAY_SYS/hw/init.rc"
    sed -i 's|^[[:space:]]*import /init\.\${ro\.hardware}\.rc|# import /init.\${ro.hardware}.rc|' "$OVERLAY_SYS/hw/init.rc"
fi

# Neutralize camera-provider and adbd in init.waydroid.rc
if [ -f "$OVERLAY_SYS/init.waydroid.rc" ]; then
    sed -i 's/^[[:space:]]*start adbd/# start adbd/' "$OVERLAY_SYS/init.waydroid.rc"
    sed -i 's/service vendor.camera-provider-2-4/service vendor.camera-provider-2-4 \/system\/bin\/true\n    disabled\n# service vendor.camera-provider-2-4/' "$OVERLAY_SYS/init.waydroid.rc"
fi




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

# Cleanly remove GPU nodes if previously added
c = c.replace('make_entry(\"/dev/ion\")\n    ', '')
c = c.replace('make_entry(\"/dev/kgsl-3d0\")\n    ', '')
c = c.replace('make_entry(\"/dev/dri\", options=\"bind,create=dir,optional 0 0\", check=False)\n    ', '')
c = c.replace('render, _ = tools.helpers.gpu.getDriNode(args)', 'render, _ = \"\", \"\"')
c = c.replace('make_entry(\"/sys/kernel/debug\", options=\"rbind,create=dir,optional 0 0\")', 'pass')

# Disable copying consumerir permissions
c = c.replace('copy_list.append(\"/vendor/etc/permissions/android.hardware.consumerir.xml\")', 'pass')
c = c.replace('copy_list.append(\"/odm/etc/permissions/android.hardware.consumerir.xml\")', 'pass')

# Redirect lxc log to persistent /var/log/waydroid_lxc.log
c = c.replace('/tmp/waydroid_lxc.log', '/var/log/waydroid_lxc.log')

# Add hardware video decoder and encoder nodes
if 'make_entry(\"/dev/video32\")' not in c:
    c = c.replace('make_entry(\"/dev/uhid\")', 'make_entry(\"/dev/uhid\")\n    make_entry(\"/dev/video32\")\n    make_entry(\"/dev/video33\")')

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
    # Ensure console logfile is persistent
    sed -i 's|/tmp/init_console.log|/var/log/init_console.log|' "$LXC_CFG" 2>/dev/null || true
fi

# Create isolated container null device to protect host /dev/null from Android chmod
[ ! -e /var/lib/waydroid/dev_null ] && mknod -m 666 /var/lib/waydroid/dev_null c 1 3 || chmod 666 /var/lib/waydroid/dev_null
chmod 666 /dev/null 2>/dev/null || true
# Ensure Qualcomm Venus hardware video nodes are accessible to container
chmod 666 /dev/video32 /dev/video33 2>/dev/null || true

# Ensure complete and safe config_nodes on disk
cat << 'EOF' > /var/lib/waydroid/lxc/waydroid/config_nodes
lxc.mount.entry = tmpfs dev tmpfs nosuid 0 0
lxc.mount.entry = /dev/zero dev/zero none bind,create=file,optional 0 0
lxc.mount.entry = /var/lib/waydroid/dev_null dev/null none bind,create=file,optional 0 0
lxc.mount.entry = /dev/full dev/full none bind,create=file,optional 0 0
lxc.mount.entry = /dev/urandom dev/urandom none bind,create=file,optional 0 0
lxc.mount.entry = /dev/random dev/random none bind,create=file,optional 0 0
lxc.mount.entry = /dev/ashmem dev/ashmem none bind,create=file,optional 0 0
lxc.mount.entry = /dev/fuse dev/fuse none bind,create=file,optional 0 0
lxc.mount.entry = /dev/tty dev/tty none bind,create=file,optional 0 0
lxc.mount.entry = /dev/kmsg dev/kmsg none bind,create=file,optional 0 0
lxc.mount.entry = /dev/null proc/sysrq-trigger none bind,optional 0 0
lxc.mount.entry = /dev/null sys/power/state none bind,optional 0 0
lxc.mount.entry = /dev/null sys/power/wake_lock none bind,optional 0 0
lxc.mount.entry = /dev/null sys/power/wake_unlock none bind,optional 0 0
lxc.mount.entry = tmpfs sys/kernel/debug tmpfs nosuid,nodev,noexec 0 0
lxc.mount.entry = tmpfs sys/kernel/tracing tmpfs nosuid,nodev,noexec 0 0
lxc.mount.entry = tmpfs sys/class/android_usb tmpfs nosuid,nodev,noexec 0 0
lxc.mount.entry = tmpfs sys/class/power_supply tmpfs nosuid,nodev,noexec 0 0
lxc.mount.entry = tmpfs sys/power tmpfs nosuid,nodev,noexec 0 0
lxc.mount.entry = /var/lib/waydroid/fake_filesystems proc/filesystems none bind,create=file 0 0
lxc.mount.entry = /dev/anbox-binder dev/binder none bind,create=file,optional 0 0
lxc.mount.entry = /dev/anbox-vndbinder dev/vndbinder none bind,create=file,optional 0 0
lxc.mount.entry = /dev/anbox-hwbinder dev/hwbinder none bind,create=file,optional 0 0
lxc.mount.entry = /dev/hwbinder dev/host_hwbinder none bind,create=file,optional 0 0
lxc.mount.entry = /vendor vendor_extra none rbind,optional 0 0
lxc.mount.entry = none dev/pts devpts defaults,mode=644,ptmxmode=666,create=dir 0 0
lxc.mount.entry = /dev/uhid dev/uhid none bind,create=file,optional 0 0
lxc.mount.entry = /dev/net/tun dev/tun none bind,create=file,optional 0 0
lxc.mount.entry = /var/lib/waydroid/host-permissions vendor/etc/host-permissions none bind,optional 0 0
lxc.mount.entry = /dev/video32 dev/video32 none bind,create=file,optional 0 0
lxc.mount.entry = /dev/video33 dev/video33 none bind,create=file,optional 0 0
lxc.cgroup2.devices.allow = c 81:* rwm
lxc.mount.entry = tmpfs mnt_extra tmpfs nodev 0 0
lxc.mount.entry = tmpfs tmp tmpfs nodev 0 0
lxc.mount.entry = tmpfs var tmpfs nodev 0 0
lxc.mount.entry = tmpfs run tmpfs nodev 0 0
EOF

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
if 'ro.hardware.egl' not in cfg['properties']:
    cfg['properties']['ro.hardware.egl'] = 'adreno'
if 'ro.hardware.gralloc' not in cfg['properties']:
    cfg['properties']['ro.hardware.gralloc'] = 'lito'
cfg['properties']['ro.hardware.hwcomposer'] = 'waydroid'
cfg['properties']['persist.waydroid.multi_windows'] = 'true'
cfg['properties']['debug.stagefright.ccodec'] = '4'
cfg['properties']['debug.stagefright.c2inputsurface'] = '1'
with open('/var/lib/waydroid/waydroid.cfg', 'w') as f:
    cfg.write(f)
" 2>/dev/null || true
fi

# 5. Disable coredump inside container to prevent kernel 4.19 do_coredump bug
cat << 'EOF' > "$OVERLAY_SYS/disable_coredump.rc"
on early-init
    write /proc/sys/kernel/core_pattern |/bin/false
    setrlimit 4 0 0
EOF

# 6. Neutralize cgroup2 freezer in cgroups.json to prevent kernel 4.19 IO error on +freezer
python3 -c "
import json, os, subprocess
tmp_mnt = '/tmp/waydroid_sys_tmp'
os.makedirs(tmp_mnt, exist_ok=True)
if os.path.exists('/usr/share/waydroid-extra/images/system.img') and not os.path.exists('$OVERLAY_SYS/../cgroups.json'):
    try:
        subprocess.run(['mount', '-o', 'ro', '/usr/share/waydroid-extra/images/system.img', tmp_mnt], check=True)
        with open(tmp_mnt + '/system/etc/cgroups.json', 'r') as f:
            data = json.load(f)
        subprocess.run(['umount', tmp_mnt], check=True)
        if 'Cgroups2' in data and 'Controllers' in data['Cgroups2']:
            data['Cgroups2']['Controllers'] = []
        with open('$OVERLAY_SYS/../cgroups.json', 'w') as f:
            json.dump(data, f, indent=2)
    except Exception:
        subprocess.run(['umount', tmp_mnt], stderr=subprocess.DEVNULL)
" 2>/dev/null || true

echo "[✓] Waydroid platform integration applied successfully."
exit 0

