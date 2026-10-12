# Graphics and Display Acceleration on Redmi K30 5G (Droidian)

## 1. Problem Summary
On Qualcomm Adreno 620 (SM7250 / lito / picasso) running Droidian GNU/Linux, launching Phoc/Phosh with hardware acceleration resulted in an immediate abort (`SIGKILL` / `00800005`) from `libGLESv2_adreno.so` inside Android container / libhybris.
Driver abort log showed:
```
Adreno-GSL: <ioctl_kgsl_syncobj_create:4451>: (19, 2, 4160) fail 22 Invalid argument
Adreno-GSL: <gsl_ldd_control:553>: ioctl fd 24 code 0x400c0907 (IOCTL_KGSL_DEVICE_WAITTIMESTAMP_CTXTID) failed: errno 35 Resource deadlock avoided
```

## 2. Root Cause
- Standard `wlroots` EGL implementation repeatedly called `eglMakeCurrent(..., EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT)` to unbind surfaces after every frame presentation or during internal texture operations (`render/gles2/texture.c`).
- On Qualcomm Adreno with `HWCNativeWindow` (libhybris), dropping the native window surface breaks syncobj timestamps and causes BufferQueue fence deadlocks on subsequent frames.

## 3. Solution & Patches
1. **Wlroots EGL Protection:**
   - Modified `render/egl.c` to preserve the active context and window surface when `egl->is_android` is true.
   - Guarded `wlr_egl_make_current` and `wlr_egl_restore_context` from unbinding or re-calling `eglMakeCurrent` unnecessarily when the context is already current.
   - Patch saved at `patches/wlroots-hwc-adreno/0001-fix-hwcomposer2-adreno-deadlock.patch`.
2. **Session Stability:**
   - Bypassed `gnome-session` timeout via `/usr/local/bin/phosh-wrapper` calling `/usr/libexec/phosh` directly.
   - Added `backlight-boot.service` to automatically restore maximum brightness (`4095`) on boot.
   - Enabled `sensorfwd` and `iio-sensor-proxy` for accelerometer, ambient light, and compass sensors.
