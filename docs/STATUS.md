# Hardware Status: Xiaomi Redmi K30 5G (`picasso`) on Droidian

Updated: October 2026

## Executive Summary
Device boots directly into hardware-accelerated Phosh UI. Physical screen output (1080x2400 @ 120Hz), touch input, battery management, Wi-Fi networking (with automatic reconnect after boot), sensors, haptics, and flashlight are fully functional.

---

## Detailed Component Matrix

### 1. Display & GPU
- **Panel:** Tianma/Huaxing 6.67" IPS LCD (1080x2400 @ 120Hz)
- **Status:** **WORKING**
- **Details:** Initialized via DSI panel driver. Surface presentation routed through `hwcomposer2` backend. Backlight managed through `/sys/class/backlight/backlight` (level 4095).
- **GPU:** Qualcomm Adreno 620
- **Driver:** Proprietary Android vendor driver (`libGLESv2_adreno.so`) via libhybris.
- **Fix Applied:** Modified wlroots EGL handling (`render/egl.c`) to avoid dropping `ANativeWindow` surface bindings, resolving driver deadlocks on `IOCTL_KGSL_DEVICE_WAITTIMESTAMP_CTXTID`.

### 2. User Shell & Compositor
- **Compositor:** Phoc 0.44+
- **Shell:** Phosh 0.44+
- **Status:** **WORKING**
- **Details:** Configured to autostart on boot via `phosh.service` with direct session wrapper, bypassing gnome-session timeouts.

### 3. Touchscreen
- **Hardware:** Novatek Capacitive Touch Controller (`NVTCapacitiveTouchScreen`)
- **Node:** `/dev/input/event2`
- **Status:** **WORKING**
- **Details:** Fully responsive multi-touch input.

### 4. Hardware Keys
- **Nodes:** `/dev/input/event0` (Power - `qpnp_pon`), `/dev/input/event1` (Volume - `gpio-keys`)
- **Status:** **WORKING**

### 5. Sensors
- **Framework:** `sensorfwd` + `iio-sensor-proxy` (`hadess-sensorfw-proxy`)
- **Status:** **WORKING**
- **Details:**
  - Accelerometer / Orientation: Streaming live data.
  - Ambient Light Sensor: Reading live lux values.
  - Compass: Streaming heading angles.

### 6. Battery & Charging
- **Driver:** Qualcomm PM7250B / SMB1396 BMS
- **Status:** **WORKING**
- **Details:** Accurate battery capacity (SOC %), voltage, current, and charge termination reporting under `/sys/class/power_supply/battery/`.

### 7. Wi-Fi
- **Chipset:** Qualcomm WCN3990
- **Driver:** in-tree `wlan.ko` (QCA CLD, `CONFIG_QCA_CLD_WLAN=m`), signed with the build-time kernel key, loaded on demand
- **Status:** **WORKING** (verified 2026-10-15 end-to-end; automatic reconnect after a full reboot verified 2026-10-16)
- **Details:** `k30-wifi.service` waits for the Android container to settle (>=240s), `insmod`s `updates/wlan.ko`, registers `/dev/wlan` and triggers FW attach; `wlan0/wlan1/p2p0` appear. Scanning, WPA2 association, DHCP and internet ping verified. NetworkManager autoconnect must stay **off** on Wi-Fi profiles (FW-attach race => silent SoC reset); `k30-wifi-init.sh` instead connects explicitly **after** bring-up (30s settle, 5 soft retries, never fails the boot). Target network: `WIFI_PROFILE=` in `/etc/default/k30-wifi`, else the profile with the highest `connection.autoconnect-priority`.

### 8. Cellular Modem
- **Chipset:** Snapdragon X52 5G (Qualcomm SDM7250)
- **Stack:** oFono + ModemManager
- **Status:** **PARTIAL**
- **Details:** Recognized as `/Modem/0`, IMEI readable (`862989044168368`).

### 9. Audio
- **Soundcard:** `lito-mtp-snd-card`
- **Stack:** ALSA + PulseAudio (`module-droid-card`)
- **Status:** **PARTIAL**
- **Details:** Audio driver chain loaded (`achain.sh`). PulseAudio server loads droid cards (`droid_card.primary`). UCM / routing rules in progress.

### 10. Bluetooth
- **Chipset:** WCN3990 Bluetooth 5.1
- **Stack:** BlueZ + `bluebinder` + kernel VHCI (built-in, `/dev/vhci`)
- **Status:** **IN PROGRESS**

### 11. USB networking & SSH
- **Interface:** `usb0` (NCM/RNDIS gadget) — device `10.15.19.82/24`; the host gets a DHCP lease from the on-device `udhcpd` (`usb-tethering.service`, package `hybris-usb`)
- **Status:** **WORKING** (SSH over USB and over Wi-Fi from the LAN)
- **Details:** The stock `usb-tethering` script uses classful `ifconfig usb0 10.15.19.82` (no netmask => `/8`); its `10.0.0.0/8` route hijacked all `10.x` subnets and broke reply routing to LAN clients (SSH via Wi-Fi stalled at the banner). Since v1.2.3, `k30-usb0-netfix.sh` (drop-in on `usb-tethering.service`, plus a capped call in `postinst`) re-asserts `10.15.19.82/24`.

## Known issues (open, 2026-10-16)

- **loop0 read errors:** the kernel logs ~15-30 `print_req_error: I/O error,
  dev loop0` per boot while reading the rootfs image `/userdata/rootfs.img`
  (image size matches the loop device, so not a truncation issue). Present on
  every recent boot and pre-dates the 2026-10-15 work. Recommend backing up
  `/userdata/rootfs.img` and running `e2fsck -f` on it from the host/recovery
  before the error pattern grows.
- **grim/screenshot:** hangs in `wl_shm` (`grim` over SSH); not fixed yet.
- **Boot races (fixed 2026-10-15 in v1.2.2):** `picasso-audio-init` used to
  give the ASoC card only 30s (card registers around t=40s+ on cold boot) and
  `nfcd` had no retry while `/dev/hwbinder` appears late — both now robust
  (5-minute audio wait, nfcd `Restart=on-failure`).
