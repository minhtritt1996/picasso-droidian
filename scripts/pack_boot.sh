#!/bin/bash
# Pack halium-boot.img with the PROVEN layout for picasso.
# Proven 2026-10-11: header v2, kernel@0x8000, ramdisk@0x1200000,
# tags@0x100, rec-picasso.dtb@0x1728000. DTB field is REQUIRED
# (images without it fall to fastboot). Ramdisk offset must clear
# the ~48MB decompressed kernel (0x1000000 overlaps -> no boot).
set -e
ROOT="${1:-$HOME/droidian}"
OUT="$ROOT/output"
# Ramdisk+DTB: prefer repo blobs (device/picasso/blobs, CI-friendly),
# fall back to legacy local paths on the build machine.
RD="$ROOT/repo/device/picasso/blobs/ramdisk.cpio.gz"
DTB="$ROOT/repo/device/picasso/blobs/rec-picasso.dtb"
[ -f "$RD" ] || RD="$ROOT/ramdisk.cpio.gz"
[ -f "$RD" ] || RD="$OUT/unpack_good2/ramdisk.cpio.gz"
[ -f "$DTB" ] || DTB="$ROOT/output/rec-picasso.dtb"
[ -f "$DTB" ] || DTB="$OUT/rec-picasso.dtb"
test -f "$RD" || { echo "missing ramdisk (see docs/02-boot-image-layout.md)"; exit 1; }
test -f "$DTB" || { echo "missing rec-picasso.dtb"; exit 1; }

CMDLINE="earlycon=msm_geni_serial,0x4a90000 androidboot.hardware=qcom androidboot.memcg=1 lpm_levels.sleep_disabled=1 msm_rtb.filter=0x237 service_locator.enable=1 swiotlb=2048 androidboot.usbcontroller=a600000.dwc3 loop.max_part=7 androidboot.usbconfigfs=true androidboot.selinux=permissive"
# NOTE: no console= param (kernel registers ttyHS0, ttyMSM0 never binds).

mkbootimg \
  --kernel "$ROOT/kernel/out_halium/arch/arm64/boot/Image.gz" \
  --ramdisk "$RD" \
  --dtb "$DTB" \
  --base 0x0 --pagesize 4096 \
  --kernel_offset 0x8000 --ramdisk_offset 0x1200000 \
  --tags_offset 0x100 --dtb_offset 0x1728000 \
  --header_version 2 --cmdline "$CMDLINE" \
  -o "$OUT/halium-boot-picasso.img"
md5sum "$OUT/halium-boot-picasso.img"
