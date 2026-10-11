# Droidian picasso port - status (2026-10-11)

## Working
- Boot: halium-boot (Lineage 4.19.248 + Proton13, RNDIS, NT36 touch, ION sysheap cfg)
  + rec-picasso.dtb (from OrangeFox recovery, proven) + fixed cmdline (NO console=ttyMSM0;
  driver registers ttyHS0 but console never binds; VT default works).
- Display once (lock screen) + touch (Novatek NVT-ts-spi) via phosh+phoc DRM/pixman.
- USB networking (10.15.19.82), SSH key auth, sudo (pw 1234).
- A11 vendor flashed (super V12.5.7.0.RGICNXM + vbmeta disabled); container HALs run
  (composer, camera, gpu, sensors HAL processes alive).

## Flashed right now
- boot: halium-boot-picasso-final.img (ION build, rec dtb, fixed cmdline)
- dtbo: dtbo-picasso-stockorder.img (21 entries, picasso idx19, from kernel out)
- super: MIUI V12.5.7.0.RGICNXM (ARB 1<=1 safe), vbmeta same + verity disabled
- recovery: OrangeFox (untouched)

## Rootfs hacks (NOT in git - fold into adaptation-picasso!)
- /etc/shadow droidian pw=1234 ($6$picassoD1$...), /home/droidian/.ssh + /root/.ssh authorized_keys (container key)
- /usr/lib/systemd/system/phosh.service.d/40-droid-wait.conf: Requires/BindsTo commented
- /etc/systemd/system/phosh.service.d/95-drm-bringup.conf: drm/gbm env (pixman line removed)
- /etc/udev/rules.d/90-panel-brightness.rules + /usr/local/bin/panel-on (1024)
- /lib/firmware/a620_zap.* copied from /android/vendor/firmware
- phosh DISABLED (autostart off) to avoid GPU-hang reboot loops
- MISSING (todo): /etc/udev/rules.d/71-android-gfx.rules (ion 0666) - only chmod done, lost on reboot

## Open problems
1. DISPLAY: wlroots pixman+DRM "Failed to create allocator"; hwcomposer swap_buffers fails;
   ANY EGL/GBM attempt wedges kgsl -> SoC watchdog reset. Suspect GPU fw/power (a620_zap)
   or missing heap config. UART would help enormously.
2. Container: lxc@android unit times out (container RUNNING), sys.boot_completed unset,
   ofono/ModemManager/sensors fail. Needs adaptation + vendor service debugging.
3. Adaptation package: skeleton researched (note10lite template), not yet built.
4. Kernel build: always clean out_halium next time (mixed state); scripts/config mishandles
   some symbols (use sed+olddefconfig); needs arm32-gcc workaround (COMPAT_VDSO off).

## Key files/locations
- Kernel src: ~/droidian/kernel (lineage-18.1, commit 5fafc5629 + clean)
- Patches: ~/droidian/patches/0001-*.patch (touch stubs)
- Boot recipe: mkbootimg header v2, base 0, kernel 0x8000, ramdisk 0x1000000, tags 0x100,
  dtb 0x1f00000 + rec-picasso.dtb + cmdline in build_*.sh
- Backups: ~/droidian/backup_picasso (persist/modem/efs), full ROM tgz in downloads/
- Phone SSH: droidian@10.15.19.82 / root@10.15.19.82 (key), pw 1234
