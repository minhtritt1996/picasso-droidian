# Feature Specification: PulseAudio System-Wide Audio & Microphone Integration

**Feature ID**: 004-system-audio-pulseaudio  
**Status**: In Progress  
**Component**: `pulseaudio` / `alsa` / `picasso-audio.service` / `adaptation-xiaomi-picasso`

## 1. Context & User Story
* **As a** user running Droidian on Xiaomi Redmi K30 5G (`picasso`),  
* **I want** system-wide sound playback (music, video, notifications, camera shutter, calls) and microphone capture to work out of the box after boot,  
* **So that** all standard GNU/Linux applications (browser, media players, camera, voice recorders) can play and record audio automatically through PulseAudio.

## 2. Requirements & Acceptance Criteria
1. **PulseAudio Automatic Card Enumeration**:
   - At system boot, once the downstream Qualcomm ASoC sound card (`litomtpsndcard`, Card 0) is probed after ADSP boot, PulseAudio must automatically register `alsa_output.0.stereo-fallback` (Playback Sink) and `alsa_input.0.stereo-fallback` (Capture Source).
2. **Default Sinks & Sources**:
   - `alsa_output.0.stereo-fallback` must be assigned as default sink.
   - `alsa_input.0.stereo-fallback` must be assigned as default source.
3. **No Boot Race**:
   - `picasso-audio-init` waits for `/dev/snd/controlC0` to appear, applies ALSA mixer paths (TFA9874 amplifier & WCD938x codec), and connects PulseAudio without failing if the sound card takes up to 60s to probe.
4. **Volume & Control**:
   - GNOME Volume slider / Phosh top bar sound menu can control output volume cleanly.

## 3. Root Cause Analysis
* At boot time (t=2s), user PulseAudio daemon starts before ADSP boots and before `kona-asoc-snd` card probes (t=40s).
* PulseAudio's `module-udev-detect` fails to re-detect card 0 without an explicit module reload or udev trigger.
* Result: `pactl list sinks short` previously only had `sink.fake.sco` (dummy null sink), rendering all user apps silent.
* Fix: In `picasso-audio-init`, after configuring ALSA mixer paths, dynamically instruct the user's PulseAudio daemon to load `module-alsa-card device_id=0` and set it as the default sink and source.
