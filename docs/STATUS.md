# Hardware Status: Xiaomi Redmi K30 5G (`picasso`) on Droidian

**Updated**: October 2026  
**Package Version**: `adaptation-xiaomi-picasso` v1.3.0

## Executive Summary
Device boots directly into hardware-accelerated Phosh UI. Physical screen output (1080x2400 @ 60Hz / 120Hz native selection with zero-jitter hardware VSync alignment, Xiaomi kernel CABC/ACL/Smart DFPS flapping completely eliminated), touch input, battery management, Wi-Fi networking (with automatic reconnect after boot), system audio & microphone via PulseAudio, Bluetooth (BlueZ/bluebinder), sensors, haptics, camera preview/video, and flashlight are fully functional.

---

## Detailed Component Matrix

### 1. Display & GPU
- **Panel:** Tianma/Huaxing 6.67" IPS LCD (1080x2400 @ 60Hz / 120Hz)
- **Status:** **WORKING**
- **Details:** 
  - Dual modes (60.00 Hz & 120.00 Hz preferred) advertised natively via `libwlroots.so.12a`.
  - Dynamic hardware config switching via HWC2 `Composer::setActiveConfig` (Config 0 = 120Hz / 8.33ms, Config 2 = 60Hz / 16.66ms).
  - Synchronous `sync_wait` 100ms stall completely eliminated from `present()`; multi-buffering runs asynchronously with zero dropped frames.
  - Screen flickering & rapid blinking eliminated via Xiaomi hardware `disp_param` lockdown: Smart DFPS 50Hz/120Hz flapping disabled (`0x50000000`), panel idle sleep disabled (`0x0B000000`), CABC dynamic PWM dimming disabled (`0x00000400`), and ACL auto-contrast disabled (`0x0000F000`).
  - Auto-brightness sensor wobble disabled (`ambient-enabled=false` in GNOME power settings).
  - Fully selectable in GNOME Settings (**Cài đặt -> Màn hình**) and via quick app shortcut (`k30-refreshrate`).
  - Surface presentation routed through `hwcomposer2` backend on Qualcomm Adreno 620 GPU (`/dev/kgsl-3d0`). Backlight managed through `/sys/class/backlight/backlight`.

### 2. User Shell & Compositor
- **Compositor:** Phoc 0.44+ (Hardware GLES2 / Adreno 620 via hwcomposer)
- **Shell:** Phosh 0.44+ (`GSK_RENDERER=cairo` for 100% stable 2D rendering without pixel corruption)
- **Status:** **WORKING**

### 3. Touchscreen
- **Hardware:** Novatek Capacitive Touch Controller (`NVTCapacitiveTouchScreen`)
- **Node:** `/dev/input/event2`
- **Status:** **WORKING** (multi-touch responsive)

### 4. Hardware Keys
- **Nodes:** `/dev/input/event0` (Power - `qpnp_pon`), `/dev/input/event1` (Volume - `gpio-keys`)
- **Status:** **WORKING**

### 5. Sensors
- **Framework:** `sensorfwd` + `iio-sensor-proxy` (`hadess-sensorfw-proxy`)
- **Status:** **WORKING** (Orientation, Ambient Light, Compass streaming live)

### 6. Battery & Charging
- **Driver:** Qualcomm PM7250B / SMB1396 BMS
- **Status:** **WORKING** (Accurate SOC %, voltage, current, charge reporting)

### 7. Wi-Fi
- **Chipset:** Qualcomm WCN3990
- **Driver:** in-tree `wlan.ko` (QCA CLD, `CONFIG_QCA_CLD_WLAN=m`)
- **Status:** **WORKING** (Automatic reconnect after boot via `k30-wifi-init.sh`)

### 8. Audio
- **Soundcard:** Qualcomm `lito-mtp-snd-card` (ASoC Card 0) via `adspboot.ko`
- **Stack:** ALSA + PulseAudio
- **Status:** **WORKING**
- **Details:** 
  - Hardware speaker routing via MultiMedia1 -> Secondary MI2S RX -> TFA9874 Smart Amplifier.
  - Microphone routing via WCD938x Soundwire Codec -> MultiMedia1.
  - Automatic PulseAudio integration via `picasso-audio-init` bridging `alsa_output.0.stereo-fallback` (Speaker) and `alsa_input.0.stereo-fallback` (Mic).
  - System-wide playback verified via `paplay`.

### 9. Bluetooth
- **Chipset:** Qualcomm WCN3990 Bluetooth 5.1
- **Stack:** BlueZ + `bluebinder` + kernel VHCI (`/dev/vhci`)
- **Status:** **WORKING**
- **Details:** Controller `FF:DD:C4:18:01:92` (Redmi K30 5G) powered on, A2DP/HFP/AVRCP profiles active.

### 10. Camera
- **Stack:** `droidian-camera` + GStreamer (`droidcamsrc`)
- **Status:** **WORKING**
- **Details:** Real-time viewfinder preview streaming from Sony IMX686 sensor. Mode transition freeze eliminated by replacing 128-radius CPU FastBlur with lightweight tint overlay. Audio/video recording configured with `voaacenc`.

### 11. USB Networking & SSH
- **Interface:** `usb0` (NCM/RNDIS gadget) — `10.15.19.82/24`
- **Status:** **WORKING** (SSH accessible simultaneously over USB and Wi-Fi LAN)

### 12. Crash Safety & Watchdog Defense
- **Status:** **SOLVED**
- **Details:** Eliminated random watchdog reboots on application SIGSEGV by setting `kernel.core_pattern = core` and `fs.suid_dumpable = 0`, bypassing the flawed downstream Linux 4.19 coredump pipe helper.
