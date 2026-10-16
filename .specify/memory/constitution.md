# Droidian Adaptation for Xiaomi Redmi K30 5G (picasso) Constitution

## Core Principles

### I. Downstream Kernel & Android HAL Boundary Isolation
- The target runs a downstream 4.19 Linux kernel (`4.19.113-lineage-picasso+`) with vendor Android 10/11 blobs in an LXC container (`lxc@android.service`).
- All vendor HAL interactions must route through `libhybris`, `/dev/binder`, and `/dev/hwbinder`. Direct bypass of the container boundaries is forbidden.
- Android init rc files (`/usr/lib/droid-vendor-overlay/etc/init/*.rc`) must strictly maintain `644 root:root` permissions; Android init skips any file with group/world-write permissions.

### II. Crash Safety & Watchdog Defense (Zero Pipe Helpers in Core Pattern)
- Pipe-based coredump helpers (`|/bin/...`) must NEVER be used on this Qualcomm 4.19 kernel. In `fs/coredump.c`, pipe helpers bypass rlimit and spawn usermodehelpers that trigger a fatal Translation Fault Kernel Oops, causing automatic watchdog reboot after 5s.
- Always enforce `kernel.core_pattern = core` and `fs.suid_dumpable = 0`. With `rlimit_core = 0`, crashing processes exit cleanly without writing core files or spawning helpers.
- Never write to `/dev/null` as a static core_pattern path, as `O_CREAT|O_TRUNC` destroys the character special device node.

### III. Split Graphics Architecture & Stability
- Compositor (`phoc`): Hardware-accelerated Adreno 620 GPU via `hwcomposer` backend + `libhybris` on `/dev/kgsl-3d0` with SDM display controller.
- System Shell (`phosh`): Cairo 2D software rasterizer (`GSK_RENDERER=cairo`) to prevent libhybris Wayland depth/stencil buffer absence and non-blocking swap buffer desync.
- Display Refresh Rate: Output modes must be advertised as fixed modes (60Hz & 120Hz preferred) via `wlr_output->modes` so GNOME Settings can natively discover and toggle refresh rates without hardcoded overrides.

### IV. Camera & Multimedia Processing
- Camera pipeline routes through `droidcamsrc` and Qualcomm hardware ISP (`vendor.camera.provider@2.4`).
- Full-screen CPU shader effects (e.g., `FastBlur` with high radius) are prohibited in QML when Mesa llvmpipe is active. Visual transitions must use lightweight opacity overlays.
- Audio and video encoding pipelines must verify caps against hardware availability before committing changes.

### V. Debian Packaging & Non-Blocking Postinst
- All hardware adaptations, overrides, and services must be packaged cleanly into `adaptation-xiaomi-picasso_<version>_arm64.deb`.
- Package installation (`postinst`) must never hang: all hardware bringup waits (e.g., USB tethering, audio sync) must be strictly capped with timeouts.
- File modes must be verified during packaging: binaries in `/usr/bin` and `/usr/local/bin` must be executable (`755`).

## Development & Review Workflow

1. **Specification First**: Before modifying device trees, HAL wrappers, or systemd services, document the objective, failure modes, and hardware dependencies in a spec file under `.specify/`.
2. **Review & Validation**:
   - Verify kernel dmesg for oopses or watchdog warnings.
   - Verify Wayland compositor and shell logs via journalctl.
   - Ensure reproducible build via `./build_adaptation_deb.sh`.
3. **Continuous Documentation**: Every bug fix and optimization must be accompanied by updated documentation in `docs/` and synced with git.

**Version**: 1.0.0 | **Ratified**: 2026-10-16 | **Project**: adaptation-xiaomi-picasso
