# Implementation Plan: PulseAudio System-Wide Audio Integration

**Feature**: `004-system-audio-pulseaudio`  
**Complexity**: Low-Medium  
**Dependencies**: `picasso-audio.service`, `pulseaudio`, `alsa-utils`

## Proposed Changes

### 1. Update `picasso-audio-init`
* File: `packages/adaptation-xiaomi-picasso/usr/local/bin/picasso-audio-init`
* Actions:
  - Keep ALSA routing for TFA9874 (speaker) and WCD938x (mic).
  - Add PulseAudio bridge:
    - Target user: `droidian` (UID 32011).
    - Environment: `XDG_RUNTIME_DIR=/run/user/32011`.
    - Check if `alsa_card.0` is already loaded; if not, invoke `pactl load-module module-alsa-card device_id=0`.
    - Set default sink to `alsa_output.0.stereo-fallback`.
    - Set default source to `alsa_input.0.stereo-fallback`.

### 2. Verify Packaging & Service Drop-in
* Package: `adaptation-xiaomi-picasso_1.2.6_arm64.deb`
* Ensure `/usr/local/bin/picasso-audio-init` has `755` permissions.
* Postinst restarts `picasso-audio.service` to apply changes immediately.

## Verification Checklist
- [x] ALSA sound card `/dev/snd/controlC0` detected
- [x] Mixer controls configured without error
- [x] PulseAudio sink `alsa_output.0.stereo-fallback` created
- [x] PulseAudio source `alsa_input.0.stereo-fallback` created
- [x] `paplay` plays audio through physical speakers
