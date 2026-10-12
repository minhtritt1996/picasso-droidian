# Audio + Bluetooth status (IN PROGRESS, not working as of 2026-10-12)

## Audio
- Kernel modules: all 31 vendor audio .ko load OK (vermagic-patched,
  dependency order in STATUS.md). No crashes from insmod.
- Machine driver binds DT `qcom,kona-asoc-snd` (audio_machine_lito.ko
  contains kona match strings). **No ALSA cards**: machine probe waits
  for ADSP, which stays OFFLINING.
- PulseAudio + module-droid: **reliably resets the SoC silently** (3x
  reproduced, no kernel logs, trap dies before crash). Suspect: ADSP PIL
  boot or first Q6 APR call from vendor HAL (TZ violation).
- ADSP firmware present in /lib/firmware (adsp.*). Modem PIL works,
  ADSP PIL never requested (audio-hal disabled by design; pulse path crashes).
- Next: force ADSP PIL boot from kernel side safely, verify ONLINE +
  stable, then ALSA, then pulse. See STATUS.md "audio" sections.

## Bluetooth (WCN3990, slimbus/btfm path)
- `bt_power` + regulators OK, rfkill unblocked, QTI BT HAL running.
- DT has `wcn3990 { compatible = "qcom,btfmslim_slave" }` (+sibling
  platform node), `btfmslim-driver` registered — but the slim slave
  **never enumerates** (only sb-1 controller). BT ROM not booting.
- Full power cycle via /dev/btpower ioctl (PWR_CTRL off/on) changes nothing.
- `btconfig` needs WDS server (not running). No UART BT node in DT
  (hci_uart path impossible without rebuild + wiring proof).
- Firmware present but unused: crbtfw32.tlv crnv32.bin crnv32u.bin.
- Next: find what boots the BT ROM (clock/reset/FW push order from stock).

## Update 2026-10-12: pulse-hidl isolated as reset trigger
- Complete unbuffered strace (4206 lines, both threads) proves pulse itself
  only retries /dev/snd/controlC* (ENOENT) + nanosleep. No DSP syscalls.
- `module-droid-hidl` (HwBinder, blocks forever waiting for miniafservice
  which does NOT exist in container) -> silent SoC reset ~40-60s later.
  WITHOUT hidl: pulse stable 320s+. Generic pulse (no droid) also stable.
- Mechanism unknown (idle blocked thread cannot reset HW; suspect delayed
  transaction or HAL .so constructor side effect via audio.primary.lito.so
  which IS dlopened at init). Needs TZ-level debugging (no UART).
- WORKAROUND for now: keep hidl disabled; droid-card alone is stable
  (but no sound without ADSP/ALSA cards).
- ADSP never boots (OFFLINING always). Next: safe PIL trigger experiments.
