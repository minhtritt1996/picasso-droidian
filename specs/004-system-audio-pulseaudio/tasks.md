# Tasks: PulseAudio System-Wide Audio Integration

- [x] Task 1: Diagnose PulseAudio state and confirm card 0 absence at boot
- [x] Task 2: Test runtime dynamic loading via `pactl load-module module-alsa-card device_id=0`
- [x] Task 3: Test playback verification using `paplay`
- [x] Task 4: Update `picasso-audio-init` script to automate PulseAudio bridge
- [x] Task 5: Bump package version to 1.2.6 in `DEBIAN/control`
- [x] Task 6: Rebuild deb package and install on device
- [x] Task 7: Reboot device or restart audio service to verify zero boot races
- [x] Task 8: Update project docs
