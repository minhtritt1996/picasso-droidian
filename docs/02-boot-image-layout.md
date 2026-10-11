# Boot image layout (PROVEN 2026-10-11, do not deviate)

- `mkbootimg`, header v2, base 0, pagesize 4096
- kernel @0x8000 (Image.gz), ramdisk @0x1200000, tags @0x100,
  DTB (rec-picasso.dtb, from OrangeFox) @0x1728000
- DTB field REQUIRED (no-DTB images fall to fastboot)
- ramdisk @0x1200000 (NOT 0x1000000): decompressed kernel is ~48MB
  and overwrites ramdisk at 16MB. (An earlier 0x134d000 attempt also
  failed; 0x4000000 without DTB failed; 0x1200000+DTB boots.)
- cmdline WITHOUT console= (see kernel/README)
- Flash: `fastboot flash boot` preferred; or dd to /dev/disk/by-partlabel/boot
  with bs + count verified by md5 (note: /dev/block/sdeNN minor numbers
  shift per boot — always resolve via PARTNAME/by-partlabel).

## Ramdisk + DTB sources (TODO: script this)
- Ramdisk: file offset 18075648, 5404482 bytes, inside a known-good
  image (halium-boot-nolCDT, md5 7fddb33d...). Do NOT use header
  ramdisk_offset (that's a RAM address, not file offset).
- DTB: file offset 23482368, 1424224 bytes, same image (magic d00dfeed).
