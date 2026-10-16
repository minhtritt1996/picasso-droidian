# WiFi bring-up (TESTED 2026-10-15, auto-connect re-verified 2026-10-16; kernel 4.19.113-lineage-g5f44e3254-dirty)

> Note: `g5f44e3254` is the pre-history-cleanup hash (working tree identical);
> old <-> new commit mapping in `AUDIT-2026-10-15.md` §7.2.

## Status: WORKING — automated by `k30-wifi.service`
Verified on hardware: scan, WPA2 association, DHCP address assignment,
internet ping (0% loss) and **automatic reconnect after a full reboot**
(2026-10-16, v1.2.3).

## Current recipe (in-tree driver, MODVERSIONS + signed modules)
1. Firmware in `/lib/firmware`: `adsp.*`, `bdwlan.*`, `bdf_*.bin`, `wlanmdsp.mbn`
   (MAC address falls back to the container's `wlan_mac.bin` via icnss sysfs).
2. `k30-wifi.service` (oneshot, `Restart=on-failure`) runs
   `/usr/local/bin/k30-wifi-init.sh`, which:
   - waits for the Android container to be RUNNING,
   - **settle gate: container must be >= 240s old**,
   - `insmod /lib/modules/$(uname -r)/updates/wlan.ko` (signed with
     `certs/signing_key.pem` from the kernel build; kernel enforces
     `CONFIG_MODVERSIONS=y` + `CONFIG_MODULE_SIG_FORCE=y`),
   - `mknod /dev/wlan c <major> 0` (major from `/proc/devices`, char dev
     name `qcwlanstate`) and `echo ON > /dev/wlan` until `wlan0` appears.
3. The char-device `ON` triggers the icnss FW download; dmesg shows
   `FW ready event received`, then `wlan0/wlan1/p2p0` are created.
4. **Auto-connect (v1.2.3):** after the interface is up the script waits a
   30s settle delay, then runs `nmcli connection up "$prof" ifname wlan0`
   (5 soft retries, always exits 0 — a failed connect never fails the unit
   or the boot). Profile from `/etc/default/k30-wifi` (`WIFI_PROFILE=`) or
   the one with the highest `connection.autoconnect-priority`.

## Hard rules (each cost multiple silent SoC resets historically)
1. **Never insmod while the container is starting** — the cnss/icnss
   FW-attach race wedges the SoC silently (no logs, no panic). The 240s
   container-age gate is mandatory.
2. **Keep NM autoconnect OFF on all Wi-Fi profiles**:
   `nmcli connection modify <name> connection.autoconnect no`.
   Autoconnect firing at interface appearance races FW attach the same way.
   Auto-connect is instead done by the init script **only after bring-up +
   settle** (recipe step 4); manual connect still works any time
   (phosh network menu, or `nmcli connection up <name> ifname wlan0`).

## Why the old flow died (regression 2026-10-15, fixed)
- Kernel now enforces `CONFIG_MODVERSIONS=y` + `CONFIG_MODULE_SIG_FORCE=y`.
  The old vendor `qca_cld3_wlan.ko` / `vmods/` set is unsigned and carries no
  CRCs -> `insmod` fails with `Required key not available`.
- `logkstub.ko` is NOT needed by the in-tree driver (it does not reference
  `uncached_logk`); it was only required by the vendor module build.
- The in-tree `wlan.ko` must be **rebuilt with every kernel build** and
  re-installed on the rootfs. `kernel/build_kernel.sh` now builds `modules`,
  strips + signs them and packs `output/kernel-modules-<release>.tar.gz`.

## Build & install the module (current procedure)
```bash
# on the build machine (same tree as the kernel build)
./kernel/build_kernel.sh ~/droidian         # also builds modules tarball
# on the device
tar xzf kernel-modules-<release>.tar.gz -C /
depmod -a $(uname -r)
systemctl restart k30-wifi.service
```

## Open
- `grim` screenshots still hang (wl_shm); separate issue, tracked in STATUS.md.
