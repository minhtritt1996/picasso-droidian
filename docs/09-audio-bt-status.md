# Audio & Bluetooth Status for Xiaomi Redmi K30 5G (`picasso`)

**Status**: **WORKING (Verified on Device)**  
**Last Updated**: 2026-10-16  
**Package Version**: `adaptation-xiaomi-picasso` v1.2.6

---

## 1. Audio System Architecture

### 1.1 Firmware & Hardware Bringup
* **DSP / ADSP PIL Boot**: Handled via `adspboot.ko` module loaded at boot time. ADSP transitions to `ONLINE` status cleanly without kernel panics or TZ violations.
* **ASoC Driver**: Qualcomm `litomtpsndcard` (kona-asoc-snd) registers ALSA Card 0 (`/dev/snd/controlC0`) with all MultiMedia PCM endpoints (MultiMedia1, MultiMedia2, VoiceMMode1, VoIP, MM_NOIRQ, etc.).
* **Hardware Routing (`picasso-audio-init`)**:
  * **Speaker**: Routed via MultiMedia1 -> Secondary MI2S RX -> TFA9874 Smart Amplifier (`amixer -D hw:0 cset name='SEC_MI2S_RX Audio Mixer MultiMedia1' 1`, `TFA Profile 0`).
  * **Microphone**: Routed via Primary & Secondary Mics -> WCD938x Soundwire Codec -> MultiMedia1 capture (`amixer` controls configured in `picasso-audio-init`).

### 1.2 PulseAudio System-Wide Integration
* **Root Cause of Earlier Silence**: PulseAudio daemon starts before ADSP finishes booting (t=40s). PulseAudio's `module-udev-detect` missed card 0.
* **Resolution**: `picasso-audio.service` runs `/usr/local/bin/picasso-audio-init`, which automatically discovers active user PulseAudio sessions in `/run/user/*` and instructs the daemon to load `module-alsa-card device_id=0`:
  * **Default Sink**: `alsa_output.0.stereo-fallback` (Stereo Speaker Playback)
  * **Default Source**: `alsa_input.0.stereo-fallback` (Stereo Mic Capture)
* **Testing**:
  * Verified playback via `paplay /usr/share/sounds/freedesktop/stereo/complete.oga`.
  * Verified volume controls in Phosh top-bar and GNOME Settings.

---

## 2. Bluetooth System Architecture

* **Hardware Controller**: Qualcomm WCN3990 (Bluetooth 5.1).
* **Stack**: Android Vendor Bluetooth HAL (`vendor.bluetooth-1-0-qti`) + `bluebinder` proxy -> Linux kernel `vhci` (`/dev/vhci`).
* **Service**: `bluebinder.service` managed by systemd.
* **Status**:
  * Controller `FF:DD:C4:18:01:92` (Redmi K30 5G) is **POWERED ON**.
  * Registered UUIDs: Headset AG, A/V Remote Control, Audio Sink/Source (A2DP), Handsfree (HFP), Generic Attribute Profile.
  * Supported channels: 1M, 2M, Coded PHY.
