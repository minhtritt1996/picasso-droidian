# picasso-droidian — Droidian (Halium 11) for Xiaomi Redmi K30 5G (`picasso`)

[![Droidian](https://img.shields.io/badge/OS-Droidian%20GNU%2FLinux-orange)](https://droidian.org)
[![Device](https://img.shields.io/badge/Device-Xiaomi%20Redmi%20K30%205G-blue)](https://wiki.postmarketos.org/wiki/Xiaomi_Redmi_K30_5G_(xiaomi-picasso))
[![Kernel](https://img.shields.io/badge/Kernel-4.19.113--lineage--picasso%2B-green)](https://github.com/minhtritt1996/picasso-droidian)
[![Spec--Kit](https://img.shields.io/badge/Spec--Kit-Enabled-blueviolet)](https://github.com/github/spec-kit)
[![Release](https://img.shields.io/badge/Adaptation-v1.3.1-success)](https://github.com/minhtritt1996/picasso-droidian/releases/tag/v1.3.1)

Port of **Droidian GNU/Linux** (Halium 11 base) for the **Xiaomi Redmi K30 5G** (`picasso` / Qualcomm Snapdragon 765G / SM7250 / Adreno 620).

Boots directly into hardware-accelerated **Phosh UI**. Full support for high-refresh display (**60Hz / 120Hz** native selection in Settings with zero-jitter hardware synchronization), Adreno 620 GPU, multi-touch, full sensors, system-wide PulseAudio sound & microphone, Bluetooth 5.1, Wi-Fi 5 (auto-reconnect after boot), camera preview & video, and battery management.

---

## 📱 Hardware Support Status (October 2026)

| Subsystem | Component / Tech | Status | Notes |
|---|---|:---:|---|
| **Boot & Kernel** | Linux 4.19.113 LineageOS (`-lineage-picasso+`), Halium-boot v2 | ✅ **WORKING** | Clean boot into userspace + LXC Android container + SSH (USB & Wi-Fi). Watchdog reboot bug eliminated. |
| **Display (60/120Hz)** | 6.67" IPS LCD (1080x2400) | ✅ **WORKING** | Native dual-mode selection (**60.00 Hz / 120.00 Hz**) with dynamic HWC2 `setActiveConfig` hardware sync. Zero flickering, zero dropped frames. |
| **GPU Acceleration** | Qualcomm Adreno 620 (`libGLESv2_adreno.so`) | ✅ **WORKING** | Hardware accelerated via GLES2/3.2 + HWC2 on `/dev/kgsl-3d0`. OpenGL ES 3.2 available via Wayland. |
| **User Interface** | Phoc (Compositor) + Phosh (Shell) | ✅ **WORKING** | Phoc runs on GPU; Phosh runs with Cairo 2D for 100% pixel-perfect stability without visual corruption. |
| **Audio & Mic** | ALSA (`litomtpsndcard`) + PulseAudio | ✅ **WORKING** | ADSP booted via `adspboot.ko`. Automatic PulseAudio bridge (`alsa_output` speaker & `alsa_input` mic). System playback verified. |
| **Bluetooth** | Qualcomm WCN3990 Bluetooth 5.1 | ✅ **WORKING** | Managed by `bluebinder.service` through kernel `/dev/vhci`. Powered on, A2DP / HFP / AVRCP profiles active. |
| **Wi-Fi** | Qualcomm WCN3990 (Wi-Fi 5) | ✅ **WORKING** | In-tree signed `wlan.ko`. Automated safe post-boot connection (`k30-wifi-init.sh`) without container race. |
| **Camera** | Sony IMX686 64MP + Front Sensors | ✅ **WORKING** | `droidian-camera` with `droidcamsrc` hardware ISP pipeline. Fast photo/video mode switching without freezes. |
| **Touchscreen** | Novatek Capacitive (`NVTCapacitiveTouchScreen`) | ✅ **WORKING** | Smooth multi-touch responsive under `/dev/input/event2`. |
| **Hardware Keys** | Power & Volume Up/Down (`qpnp_pon`, `gpio-keys`) | ✅ **WORKING** | Registered under `/dev/input/event0` and `/dev/input/event1`. |
| **Sensors** | Sensorfw + `iio-sensor-proxy` | ✅ **WORKING** | Accelerometer, Ambient Light Sensor, Compass streaming live data. |
| **Battery & Charging** | Qualcomm SMB1396 / PM7250B BMS | ✅ **WORKING** | Accurate SOC %, voltage, current, and thermal charging control under `/sys/class/power_supply/battery/`. |
| **Haptics & Torch** | Vibrator + Dual-LED Flash | ✅ **WORKING** | Controlled via `/sys/class/timed_output/vibrator` and `/sys/class/leds/led:torch_*`. |
| **Cellular Modem** | Snapdragon X52 5G (oFono + ModemManager) | ⚠️ **PARTIAL** | Modem detected (`/Modem/0`), IMEI readable. Power management ready. |

---

## 🛠️ Key Technical Fixes & Architecture

### 1. Watchdog Bite & Kernel Oops Elimination (SIGSEGV Safety)
* **Problem**: Application crashes (SIGSEGV) caused immediate kernel panic and watchdog reboot after 5 seconds.
* **Root Cause**: `/etc/sysctl.d/99-disable-coredump.conf` used `kernel.core_pattern = |/bin/false`. On downstream Qualcomm 4.19 kernels, piping coredumps triggers a fatal Translation Fault Kernel Oops in `call_usermodehelper`.
* **Solution**: Configured `kernel.core_pattern = core` and `fs.suid_dumpable = 0`. With standard `rlimit_core = 0`, the kernel immediately skips coredump processing without invoking helpers or writing files. Crashing processes now exit cleanly with code `139` without rebooting.

### 2. Screen Flickering, Jitter & Stutter Elimination (Dynamic HWC2 `setActiveConfig` & Xiaomi Hardware Display Lockdown)
* **Problem**: UI animations stuttered, and the screen exhibited rapid flickering / blinking / micro-jitter ("nhảy nhảy màn hình") even when stationary.
* **Root Causes**:
  1. **Kernel Smart DFPS Mode Flapping**: In Qualcomm/Xiaomi display driver (`xiaomi_frame_stat.c` & `dsi_panel_mi.c`), proprietary Smart DFPS was enabled by default. Whenever frame interval exceeded 70ms (`skip_count >= 3`), the kernel throttled the panel to 50Hz (`DISPPARAM_DFPS_LEVEL2`), then instantly snapped back to 120Hz the moment a frame arrived. This mode flapping triggered `ALERT: changing window size from 8000000 to 20000000` 3-4 times every second, causing panel clock re-syncing and visible screen blinking.
  2. **CABC & ACL Backlight Modulation**: Content Adaptive Backlight Control (`DISPPARAM_CABCUI_ON`) and Auto-Contrast Luminance (`DISPPARAM_ACL_L1`) dynamically altered IPS backlight PWM based on frame pixels.
  3. **Auto-Brightness Sensor Wobble**: GNOME power daemon plugin had `ambient-enabled=true`, oscillating backlight on ambient sensor noise.
  4. **Sync-Wait & Fence Leaks**: `hwcomposer2_present()` blocked synchronously on `sync_wait` (100ms timeout), and leaked release fences, pushing CPU load to 10.91.
* **Solution**:
  1. **Hardware Display Lockdown**: Locked Xiaomi hardware display parameters via `/sys/devices/platform/soc/ae00000.qcom,mdss_mdp/drm/card0/card0-DSI-1/disp_param`:
     - `0x0B000000` (`DISPPARAM_IDLE_OFF`): Panel idle sleep disabled.
     - `0x00000400` (`DISPPARAM_CABC_OFF`): CABC dynamic backlight modulation disabled.
     - `0x0000F000` (`DISPPARAM_ACL_OFF`): ACL auto-contrast disabled.
     - `0x50000000` (`DISPPARAM_DFPS_LEVEL5` & Smart DFPS off): Locked 120Hz refresh rate and stopped 50Hz mode flapping permanently.
  2. **Wlroots Synchronous Hook**: Patched `libwlroots.so.12a` to write to `disp_param` synchronously on mode switches (0x50000000 for 120Hz, 0x30000000 for 60Hz) and initial presentation.
  3. **Async Pipeline**: Removed blocking `sync_wait`, drained fences, and dropped CPU load average from 10.91 to ~1.0.
  4. **Auto-Brightness Lockdown**: Set `ambient-enabled=false` in GNOME power settings.


### 3. Native 60Hz & 120Hz Display Refresh Rate in Settings
* **Problem**: GNOME Control Center (Settings -> Displays) hid the refresh rate selection entirely.
* **Root Cause**: `wlr_hwcomposer_add_output` in wlroots only configured a single custom mode, leaving `wlr_output->modes` empty.
* **Solution**: Patched `libwlroots.so.12a` to register both `1080x2400 @ 60.00 Hz` and `1080x2400 @ 120.00 Hz (preferred)` into `output->modes`, handled dynamic `WLR_OUTPUT_STATE_MODE` in `output_commit`, and removed hardcoded 60Hz overrides in `/etc/phosh/phoc.ini`.

### 4. Camera Freeze Elimination on Video Switch
* **Problem**: Switching `droidian-camera` from Photo to Video mode completely locked up the CPU and froze the app.
* **Root Cause**: `main-gst.qml` applied `FastBlur` with `radius: 128` across 1080x2400 pixels during mode transition. Because Qt renders via CPU llvmpipe, calculating a 128-radius Gaussian blur across 2.6 million pixels pegged all CPU cores at 100%, starving the Qt event loop.
* **Solution**: Replaced FastBlur/Glow with a lightweight opacity overlay (`#40000000`), patched `droidian-camera.bin` to load optimized `/etc/c.qml`, and fixed recording pipeline encoders (`voaacenc`).

### 5. System-Wide PulseAudio Integration
* **Problem**: PulseAudio had no ALSA sinks after boot; apps were silent.
* **Root Cause**: PulseAudio daemon starts at t=2s, but the ASoC sound card registers at t=40s after ADSP boots. PulseAudio's `module-udev-detect` missed card 0.
* **Solution**: Enhanced `picasso-audio-init` to automatically instruct active user PulseAudio sessions to load `module-alsa-card device_id=0`, setting `alsa_output.0.stereo-fallback` (speaker) and `alsa_input.0.stereo-fallback` (mic) as defaults.

### 6. Adreno 620 EGL & HWComposer Deadlock Fix
* **Problem**: Phoc crashed with `SIGKILL` on Adreno 620 due to `IOCTL_KGSL_DEVICE_WAITTIMESTAMP_CTXTID` (Resource deadlock avoided).
* **Solution**: Patched wlroots `render/egl.c` to preserve `ANativeWindow` surface bindings under libhybris.

### 7. Screen Jitter / Position Jumping Elimination (One-Shot VSync & Triple Buffering)
* **Problem**: When opening Settings (`gnome-control-center`), the list and display jumped/vibrated violently up and down, only stopping while the user physically touched the screen.
* **Root Causes**:
  1. `schedule_frame()` in wlroots `backend/hwcomposer/output.c` configured a repeating `timerfd` (`.it_interval = interval_tspec`), generating unthrottled 120 FPS render ticks even when the system was completely idle.
  2. The buffer queue used 8 buffers (`HWCNativeWindowSetBufferCount(8)`). When Settings resized dynamically to account for the top notch, stale full-screen (2400h) and fitted (2306h) buffers were presented out of order by Qualcomm HWC2.
* **Solution**:
  1. Changed `timerfd` to a **one-shot timer** (`.it_interval = {0, 0}`). Phoc now renders strictly on damage, dropping idle CPU from 100% to 0.0%–2.0%.
  2. Enforced standard **Triple Buffering** (`HWCNativeWindowSetBufferCount(3)`), completely eliminating out-of-order frame jumping.

### 8. Full GNOME Session Daemons, Native Brightness Slider, Torch & Communications
* **Problem**: Calls (`gnome-calls`) and Chats (`chatty`) failed to launch (`result 'dependency'`); the brightness slider, quick-settings Torch button, and Bluetooth control were inactive.
* **Root Cause**: Phosh was previously launched standalone (`/usr/libexec/phosh -U`), bypassing `gnome-session`. Consequently, `gnome-session-initialized.target` was never reached, preventing all dependent daemons from starting.
* **Solution**:
  1. Integrated `exec gnome-session --session=phosh` into `phosh-wrapper`, properly activating `gnome-session.target`, `gnome-session-initialized.target`, and all GNOME Settings Daemons (`gsd-power`, `gsd-rfkill`, `gsd-media-keys`, `gsd-color`).
  2. Created custom `/usr/local/lib/libdroid_fix.so` translating `droid_leds` calls directly to kernel `/sys/class/backlight/panel0-backlight/brightness`, giving 100% accurate, smooth backlight slider control.
  3. Configured `flashlightd` sysfs node `/sys/class/leds/flashlight/brightness` and udev permissions (0666), enabling native Quick Settings Torch toggling.
  4. Calls and Chats services now start automatically and respond instantaneously to UI clicks and incoming telephony/SMS events.

### 9. Dual Front Camera Punch-Hole Status Bar Safezone & Kernel Hardening (v1.3.1)
* **Problem**: The dual front selfie cameras (pill cutout at top-right corner, physical bounds X: 854–1090, Y: 0–95) physically covered the 32px logical (64px physical) status bar, cutting 31px down into full-screen application headers (e.g. Calls tabs "Recent", "Contacts", "Dial Pad"). Moreover, status indicators (battery %, location) sat directly underneath the camera glass.
* **Solution**:
  1. **Status Bar Height Expansion (54px logical = 108px physical)**: Intercepted Wayland layer shell surface requests in [`libdroid_fix.so`](packages/adaptation-xiaomi-picasso/usr/local/lib/libdroid_fix.so) (`zwlr_layer_surface_v1_set_size`, `set_exclusive_zone`, and `zphoc_draggable_layer_surface_v1_set_margins` / `set_exclusive`). The status bar exclusive zone now expands cleanly to 54px (108px physical), completely enclosing the 95px camera cutout within the black bar. All app headers now start cleanly at Y=108px with zero obstruction.
  2. **Indicator Safezone Shift**: Configured GTK CSS `#box_indicators { padding-right: 135px; }`, shifting the battery % and status icons to end at X=845px physical (left of X=854px camera edge), keeping the camera cutout zone 100% black and uncluttered.
  3. **Kernel Coredump & Watchdog Hardening**: Disabled userspace coredump piping to prevent Qualcomm translation fault oopses (`/etc/sysctl.d/99-disable-coredump.conf`), added missing Qualcomm Venus video firmware (`venus.*`) and Camera ICP firmware (`CAMERA_ICP.elf`), and moved `k30-pmic-pet.service` to early sysinit (`DefaultDependencies=no`, `Before=basic.target sysinit.target`) to eliminate reboot loops and PMIC hardware watchdog pet starvation.

---

## 📐 Spec-Driven Development (GitHub Spec Kit)

This repository follows the **Spec-Driven Development (SDD)** methodology powered by [GitHub Spec Kit](https://github.com/github/spec-kit) with native **Antigravity** (`agy`) integration:

* **[`.specify/memory/constitution.md`](.specify/memory/constitution.md)**: Project Constitution defining non-negotiable principles for Android HAL boundaries, kernel crash safety, GPU vs Cairo rendering, and Debian packaging standards.
* **[`specs/`](specs/)**: Executable feature specifications, architectural plans, and task breakdowns:
  * [`specs/001-camera-optimization/`](specs/001-camera-optimization/spec.md): Camera viewfinder and mode transition spec.
  * [`specs/002-display-refresh-rate/`](specs/002-display-refresh-rate/spec.md): Native 60Hz/120Hz display modes spec.
  * [`specs/003-crash-safety-watchdog/`](specs/003-crash-safety-watchdog/spec.md): Watchdog reboot & coredump safety spec.
  * [`specs/004-system-audio-pulseaudio/`](specs/004-system-audio-pulseaudio/spec.md): PulseAudio automatic bridge spec.

---

## 📦 Building & Packaging

### 1. Build the Hardware Adaptation Debian Package
All device configurations, services, binaries, and udev rules are packaged into a standalone `.deb`:
```bash
./build_adaptation_deb.sh
# Output: output/adaptation-xiaomi-picasso_1.2.6_arm64.deb
```

Install on device:
```bash
scp output/adaptation-xiaomi-picasso_1.2.6_arm64.deb root@10.15.19.82:/tmp/
ssh root@10.15.19.82 "dpkg -i /tmp/adaptation-xiaomi-picasso_1.2.6_arm64.deb"
```

### 2. Build Kernel & Boot Image
```bash
# 1. Build kernel (Image.gz + dtbs + modules tarball)
./kernel/build_kernel.sh ~/droidian

# 2. Pack boot image
./scripts/pack_boot.sh ~/droidian

# 3. Flash to device (Fastboot mode)
fastboot flash boot output/halium-boot-picasso.img
```

---

## 📂 Repository Layout

```
├── .specify/             # GitHub Spec Kit configuration, constitution, scripts, templates
├── .agents/skills/       # Spec Kit skills (speckit-specify, speckit-plan, speckit-tasks, etc.)
├── specs/                # Feature specifications, plans, and verification tasks
├── packages/
│   └── adaptation-xiaomi-picasso/   # Debian adaptation package source tree
│       ├── DEBIAN/                  # Control, conffiles, and postinst scripts
│       ├── etc/                     # System configs (phoc.ini, asound.conf, udev, c.qml)
│       ├── usr/bin/                 # Patched binaries (droidian-camera.bin)
│       ├── usr/lib/                 # Patched libwlroots.so.12a and vendor overlays
│       └── usr/local/bin/           # Helper daemons (k30-refreshrate, picasso-audio-init)
├── docs/                 # Detailed technical logs and status documents
├── build_adaptation_deb.sh # Automated package builder
└── README.md
```

---

## 📜 License & Credits

* **Maintainer**: Minh Tri ([@minhtritt1996](https://github.com/minhtritt1996))
* Base system: [Droidian GNU/Linux](https://droidian.org)
* HAL layer: [Halium Project](https://halium.org)
* Spec Toolkit: [GitHub Spec Kit](https://github.com/github/spec-kit)
