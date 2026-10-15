# picasso-droidian — Droidian (Halium 11) for Redmi K30 5G (picasso)

Port of Droidian GNU/Linux (Halium 11 base) for the Xiaomi Redmi K30 5G (`picasso`, Qualcomm Snapdragon 765G / SM7250 / Adreno 620).

Boots directly into hardware-accelerated Phosh UI. Full support for physical display (1080x2400@120Hz), Novatek touchscreen, sensors (accelerometer, ambient light, compass), Wi-Fi, battery charging management, and cellular modem.

---

## 📱 Hardware Support Status

| Subsystem | Component / Tech | Status | Notes |
|---|---|:---:|---|
| **Boot & Kernel** | Linux 4.19.113 LineageOS, Halium-boot v2 | ✅ **WORKING** | Boots directly to userspace + LXC Android container + SSH (USB RNDIS / Wi-Fi). Module enforcement: MODVERSIONS + signatures (`-lineage-picasso+` releases). |
| **Display** | 6.67" IPS LCD (1080x2400 @ 120Hz) | ✅ **WORKING** | Panel initialization via DSI. Persistent backlight control (`4095/4095`). |
| **GPU Acceleration** | Qualcomm Adreno 620 (`libGLESv2_adreno.so`) | ✅ **WORKING** | Hardware accelerated via GLES2/3.2 + HWC2. Wlroots deadlock bug resolved. |
| **User Interface** | Phoc (Compositor) + Phosh (Shell) | ✅ **WORKING** | Stable execution bypassed gnome-session timeout via direct wrapper. Autostarts on boot. |
| **Touchscreen** | Novatek Capacitive (`NVTCapacitiveTouchScreen`) | ✅ **WORKING** | Responsive input registered under `/dev/input/event2`. |
| **Hardware Keys** | Power & Volume Up/Down (`qpnp_pon`, `gpio-keys`) | ✅ **WORKING** | Registered under `/dev/input/event0` and `/dev/input/event1`. |
| **Sensors** | Sensorfw + `iio-sensor-proxy` | ✅ **WORKING** | Accelerometer, Ambient Light Sensor, and Compass streaming data in real-time. |
| **Battery & Charging** | Qualcomm SMB1396 / PM7250B BMS | ✅ **WORKING** | Battery percentage, voltage, and charging thermal regulator fully reported. |
| **Haptics & Flash** | Vibrator motor + Dual-LED Flash | ✅ **WORKING** | Controllable via `/sys/class/timed_output/vibrator` and `/sys/class/leds/led:torch_*`. |
| **Wi-Fi** | Qualcomm WCN3990 (Wi-Fi 5) | ✅ **WORKING** | Signed in-tree `wlan.ko`, loaded by `k30-wifi.service` after container settle. Scan + WPA2 + DHCP + internet verified (2026-10-15). Keep NM autoconnect **off** on Wi-Fi profiles. |
| **Cellular Modem** | Snapdragon X52 5G (oFono + ModemManager) | ⚠️ **PARTIAL** | Modem detected (`/Modem/0`), IMEI readable. Power management ready. |
| **Audio** | ALSA + PulseAudio (`lito-mtp-snd-card`) | ⚠️ **PARTIAL** | Kernel soundcard registered; PulseAudio starts with `droid_card.primary`. |
| **Bluetooth** | Qualcomm WCN3990 Bluetooth 5.1 | ⚠️ **IN PROGRESS** | BlueZ active, `hci_vhci.ko` loaded, proxying through `bluebinder`. |
| **Camera** | 64MP Quad Rear + Dual Front | ⚠️ **TODO** | V4L2 device nodes present (`/dev/video*`, `/dev/media*`), requires camera stack integration. |

---

## 🛠️ Key Technical Fixes

### 1. Adreno 620 EGL & HWComposer Deadlock Fix
- **Problem:** When starting Phoc with GLES2 on Qualcomm Adreno 620, the proprietary driver (`libGLESv2_adreno.so`) crashed with `SIGKILL` (`00800005`) due to `IOCTL_KGSL_DEVICE_WAITTIMESTAMP_CTXTID` (Resource deadlock avoided).
- **Cause:** Wlroots by default called `eglMakeCurrent(..., EGL_NO_SURFACE, ...)` after every frame and during texture uploads. Unbinding the `ANativeWindow` surface breaks Adreno GSL internal buffer-sync tracking on libhybris.
- **Solution:** Patched `render/egl.c` to maintain context and native surface binding when running under Android/libhybris. See [patches/wlroots-hwc-adreno/0001-fix-hwcomposer2-adreno-deadlock.patch](patches/wlroots-hwc-adreno/0001-fix-hwcomposer2-adreno-deadlock.patch).

### 2. Phosh Session Auto-start & Stability
- Created `/usr/local/bin/phosh-wrapper` and systemd drop-in `60-direct-phosh.conf` to avoid `gnome-session` timeout termination.
- Created `backlight-boot.service` ensuring physical screen backlight turns on at maximum brightness (`4095`) automatically upon boot.
- Enabled `sensorfwd.service` and `iio-sensor-proxy.service` linking Android Sensors HIDL to Linux desktop environment.

---

## 📂 Repository Layout

- `device/picasso/` — Target device configurations, systemd services, drop-ins, and scripts.
  - `systemd/60-direct-phosh.conf`: Direct Phosh session drop-in.
  - `systemd/backlight-boot.service`: Persistent backlight boot service.
  - `systemd/phosh-wrapper.sh`: Wrapper launcher.
- `patches/` — Patches for upstream libraries.
  - `wlroots-hwc-adreno/`: Adreno 620 BufferQueue synchronization fix for wlroots 0.18.
- `kernel/` — Kernel defconfig, patches, and build scripts.
- `docs/` — Detailed engineering and bringup documentation.
  - `docs/10-graphics-and-display-acceleration.md`: Complete graphics acceleration postmortem.
  - `docs/08-wifi-bringup-tested.md`: Wi-Fi driver bringup procedure.
  - `docs/09-audio-bt-status.md`: Audio and Bluetooth subsystem notes.
  - `docs/STATUS.md`: Detailed hardware subsystem matrix.

---

## 🚀 Building & Flashing

```bash
# 1. Build kernel (Image.gz + dtbs + modules tarball)
./kernel/build_kernel.sh ~/droidian

# 2. Pack boot image
./scripts/pack_boot.sh ~/droidian

# 3. Flash to device (via fastboot)
fastboot flash boot output/halium-boot-picasso.img

# 4. Install kernel modules on the device rootfs — REQUIRED after every
#    kernel build (Wi-Fi/audio modules must match the flashed kernel):
#    on the device: tar xzf kernel-modules-<release>.tar.gz -C /
```
