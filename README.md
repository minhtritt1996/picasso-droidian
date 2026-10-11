# picasso-droidian — Droidian (Halium 11) for Redmi K30 5G (picasso)

Boots to console + SSH + USB networking. Touch works. Modem alive (no SIM
tested). WiFi works (automated). Display/audio/BT in progress.

## Status

| Area | State |
|---|---|
| Boot (halium-boot.img, header v2) | ✅ TESTED |
| Display/touch (DRM+pixman once, touch OK) | ⚠️ compositor masked (GPU wedges kgsl, see docs) |
| Modem (ofono/MM, IMEI readable) | ✅ TESTED (sim-missing, no SIM in slot) |
| Sensors HALs + sensorfwd | ✅ running, data flow untested |
| WiFi (scan/connect/ping, automated service) | ✅ TESTED |
| DroidSpaces core (ns/cgroup/overlay/iptables NAT44) | ✅ TESTED |
| DroidSpaces limits/NAT66/ipset | ❌ deferred (crash vendor wifi, see docs) |
| Audio | ❌ pulse+droid-HAL resets SoC (see docs/09) |
| Bluetooth | ❌ ROM never enumerates (see docs/09) |

Details: `docs/STATUS.md`, `docs/STATUS-wifi-ds.md`.

## Layout
- `kernel/` — defconfig + patches + build script (no full tree; CI clones upstream)
- `device/picasso/` — rootfs files (systemd/udev/sysctl/pulse/firmware lists)
- `scripts/` — pack/flash boot.img (proven layout)
- `docs/` — tested procedures (08-wifi) and status (09-audio-bt)
- `.github/workflows/` — CI kernel build

## Quickstart (build machine)
```bash
./kernel/build_kernel.sh ~/droidian
./scripts/pack_boot.sh ~/droidian
# flash: fastboot flash boot output/halium-boot-picasso.img (or dd, see docs)
```
Ramdisk + DTB sources: see `docs/02-boot-image-layout.md` (TODO: document
extraction from a known-good image).
