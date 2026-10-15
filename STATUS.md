# picasso (Redmi K30 5G) — Droidian status

Updated: 2026-10-15 (post-audit + fixes)

Live, verified state of the connected device. Details live in `docs/`
(start with `docs/STATUS.md` and `docs/AUDIT-2026-10-15.md`).

## Working (verified on hardware)
- **Boot:** halium-boot (Lineage 4.19.113 kernel). Kernel release format is
  `4.19.113-lineage-picasso+` (LOCALVERSION fixed, AUTO off); modules are
  MODVERSIONS + signature enforced.
- **UI:** phoc + phosh on Adreno 620 (wlroots HWC patch), 1080x2400 @ 120Hz scale 2.
- **Input/sensors:** Novatek touch, power/volume keys, accelerometer/ALS/compass,
  battery + charging, haptics, flashlight.
- **Wi-Fi:** in-tree signed `wlan.ko` loaded by `k30-wifi.service` after the
  container settles; scan/WPA2/DHCP/internet verified 2026-10-15.
  NetworkManager autoconnect stays **off** on Wi-Fi profiles.
- **Audio:** in-kernel techpack audio (`lito-mtp-snd-card`, PulseAudio running).
- **Modem:** `/Modem/0` detected (oFono + ModemManager).
- **SSH:** key auth for `root@10.15.19.82` and `droidian@10.15.19.82`.
  Default passwords were rotated on 2026-10-15 (ask the operator; not in git).

## Flashed / installed state
- boot image: `output/halium-boot-picasso.img` (md5 `8f911039d22f443fb6114866d8610e03`).
- adaptation-xiaomi-picasso **v1.2.0** — signed `wlan.ko`, `k30-wifi.service` v2,
  `k30-display-power.service`, boot-completed drop-in, memtrack overlay.
- Android container: `memtrack-hal` disabled (vendor overlay), `sys.boot_completed`
  set via the container's own `setprop`; journal vacuumed (800M -> ~70M).

## Open / next
- **Bluetooth:** slim slave never enumerates (see `docs/09-audio-bt-status.md`).
- **Camera:** V4L2 nodes present, stack not integrated.
- **grim screenshots** hang (wl_shm); isolate before relying on screenshots.
- DroidSpaces limits/NAT66/ipset (see `docs/STATUS-wifi-ds.md`, historical).

## Build & flash
```bash
./kernel/build_kernel.sh ~/droidian   # Image.gz + modules tarball
./scripts/pack_boot.sh ~/droidian     # output/halium-boot-picasso.img
fastboot flash boot output/halium-boot-picasso.img
# on the device: install modules matching the flashed kernel
tar xzf kernel-modules-<release>.tar.gz -C / && depmod -a $(uname -r)
```
