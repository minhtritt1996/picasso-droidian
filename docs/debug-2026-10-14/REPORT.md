# Chẩn đoán màn hình đen Redmi K30 5G (picasso) — phiên 13→14/10/2026

## Kết luận nhanh
- Panel + backlight SỐNG (DSI ON, 1080x2400, backlight điều khiển được).
- HWC present chạy (`err=0`, hàng nghìn frame), nhưng nội dung ĐEN 100% (grim screenshot `avg 0.0`).
- GLES context chết xác định mỗi boot: `gpu fault ... ts 1 status 00800005` → `gpu failed ts 2` → `EGL_CONTEXT_LOST`.
- Vendor EGL/GLES (Qualcomm ES 3.2) test tối giản: init/surface/ctx/compile/link/draw/swap đều OK, KHÔNG fault,
  nhưng mọi readback = 0, kể cả loopback GPU→GPU (texture). → **GPU ghi không dính / đọc stale, dưới mọi userspace.**
- Reboot lặp 1–9 phút: do stack display (mask phosh+lxc = sống 7–9 phút ổn định).
- Mọi revert/bisect wlroots đều fault y hệt → bệnh nằm dưới wlroots (driver vendor ↔ kernel kgsl/ion/smmu).

## Chi tiết theo bước
1. Uptime + ổn định nền: mask `phosh+lxc` → up 7–9 phút, load ~0.1. Bỏ mask + chạy stack → reset 1–4 phút.
2. Panel/mode: `card0-DSI-1` có 120/90/60/50/30Hz. Test 60Hz: fault Y HỆT 120Hz → loại tần số quét.
3. Screenshot grim: đen tuyệt đối (3 lần, gồm cả sau present#1380).
4. `test_hwcomposer` (libhybris-test): treo → reset, bỏ.
5. GMU snapshot: `/sys/kernel/debug/kgsl/snapshot/` chỉ có núm điều khiển, không có dump. Hướng cụt.
6. ftrace kgsl (`adreno_cmdbatch_*`, `adreno_gpu_fault`): enable được nhưng 0 entries → event không fire trên kernel này. Cụt.
7. Bắt fault đầy đủ 1 boot (`root/kgsl-fault-dmesg.txt` 5781 dòng): fault ~1–3s sau output add,
   TRƯỚC cả lockscreen → chết ở render nền của chính phoc, không phải content client.
8. EGL tối giản (`egltests/`): pbuffer clear/swap/readpixels, triangle shader compile+link+draw,
   texture loopback — tất cả API sạch, không fault, pixel luôn 0.
9. GBM/native probe (`eglinfo -B`): treo → reset. Đường native xác nhận nguy hiểm, cấm đụng renderD128/GBM.
10. Phát hiện file `.bak` (lib strip 12/10) và bản vahel-deb (1.4M) đều chứa fix nhưng đều fault → không phải do build.
11. Đọc patch `0001-fix-hwcomposer2-adreno-deadlock.patch`: doc `10-graphics` mô tả sai
    (không hề có guard `eglMakeCurrent`; chỉ có: bỏ sync_wait/dup/SetFence, share 1 EGLSurface,
    bỏ DEPTH/STENCIL, tắt priority/robustness, threading output).
12. Bisect trên `/root/wlroots` (meson+ninja, build trực tiếp trên máy):
    - revert share-surface → per-buffer: vẫn fault (IB đổi địa chỉ).
    - restore DEPTH24/STENCIL8: vẫn fault.
    - vá fence đúng (acquire passthrough + sync_wait timeout 100ms + dup/SetFence): present tăng 6→24–48,
      `acq=46` thật (hết -1), nhưng vẫn fault + đen.
    - revert output-threading render.c: vẫn fault → khôi phục lại (đúng).
    - thêm đợi release 50ms trước render (bind path + field `hwc_last_present_fence` mới): vẫn fault + đen.
    - frame#1 present OK rồi mới CONTEXT_LOST ở frame#2 → chết ở render tái sử dụng buffer.
13. `/tmp/draw_white` hook có sẵn trong lib nhưng vô hiệu (ctx chết trước swap; hook nằm sau điểm fault).
14. Blob vendor (super V12.5.7) đồng bộ, đủ (composer 1.0/2.0/3.0, libsdmcore, a620_zap load OK). Không underflow MDP.
15. Nhiệt 37–42°C (không quá nhiệt), UFS rule đã cài, không lỗi UFS.

## Thay đổi trên máy (đã cài)
- `/usr/lib/aarch64-linux-gnu/libwlroots.so.12a` = bản build `86db8b30` (tổng hợp mọi fix trên).
  Các bản cũ còn giữ: `.bak` (Oct12), `.dbg-today`, `.pre-bisect1`.
- `/etc/phosh/phoc.ini`: scale=2 + 60Hz cả 2 section (đang chạy).
- `/etc/systemd/system/phosh.service{lxc@android.service}` → mask (giữ máy sống).
- Source đã sửa ở `/root/wlroots` — **đã kéo toàn bộ về `docs/debug-2026-10-14/wlroots-current/`.

## Bài học vận hành (xương máu)
- Mỗi `systemctl restart phosh` / `lxc-stop` đều có thể kích reset (TZ-kill). Không bao giờ `lxc-stop`.
- Mask xong phải `sync` + verify `ls -l` (reset sớm làm mất write không sync — từng mất file 0-byte).
- `systemctl stop phosh` không giết được phoc con → dùng `pgrep` verify, cần thì kill PID trực tiếp.
- Mọi chạm vào GPU/GBM đều có thể reset → build dùng `ninja -j2`, thao tác đọc trước.
- Cổng 2323 lúc mở lúc đóng, câm hoàn toàn — không dùng cứu hộ được. Mất SSH ⇒ chỉ còn reboot vật lý.

## Đề xuất tiếp theo
1. Ưu tiên: kernel kgsl/smmu/ion (coherency attrs, SMMU context bank gfx3d, ION system heap flags) — source có sẵn `kernel/`.
   Đối chiếu kgsl driver với Lineage gốc + shim UAPI syncobj cho blob A11.
2. So sánh blob Adreno (libGLESv2_adreno) với bản Lineage/MIUI khác — KHÔNG flash super lạ (ARB=1, nguy cơ brick).
3. Viết test EGL window-surface tối giản qua HWC native window (cách ly window khỏi phoc).
4. Đồng bộ patch repo (`patches/wlroots-hwc-adreno/`) với source trên máy (hiện repo tụt hậu: thiếu
   release-fence/power-force/composition/fence-fix/bind-wait/draw-hooks).

## File kèm theo
- `wlroots-current/`: 7 file nguồn wlroots trên máy sau mọi chỉnh sửa (+ `hwcomposer.h`).
- `egltests/egltest{,2,3,4,5}.c`: test EGL tối giản (pbuffer, swap, triangle, texture loopback,
  surfaceless+FBO qua Mesa — bản Mesa cho pixel ĐỎ đúng 255,0,0,255).
- `fault-logs/`: `kgsl-fault-dmesg.txt` (full dmesg 1 boot fault), `kgsl-fault-phoc.txt` (33 dòng log phoc).
- `phoc.ini`: config đang chạy trên máy.

## Bổ sung sau commit đầu (phiên tiếp theo cùng ngày)
- fence fix + đợi release 50ms trước render (field mới `hwc_last_present_fence`): present tăng,
  acquire fence thật (`acq=46`), nhưng fault + đen không đổi.
- `SetBufferCount(3→2)`: không đổi.
- Ép GPU clocks/rails (`force_clk_on/rail/bus/no_nap`, 275MHz): fault y hệt → loại power-mgmt.
- Mesa surfaceless+FBO: pixel ĐỎ đúng → kernel/memory vô tội; bệnh khoanh vào vendor/hybris path.
- hybris `test_egl_configs` OK (68 configs); `test_glesv2` abort ở `create_hwcomposer_window`
  (cần HWC service) — kèm reset máy.
- GBM probe (`eglinfo -B`): treo → reset. Cấm đụng renderD128/GBM.
- Không fbcon (`/dev/fb*` không tồn tại) → loại xung đột console.
- UFS rule đã cài, không lỗi UFS. Nhiệt 35–42°C. Charger wdog tự pet.
- ftrace kgsl events tồn tại nhưng không fire. `/dev/mem` không tồn tại. Snapshot kgsl không expose.
- Boot idle (mask đầy đủ) cũng reset sau ~10–20 phút — còn 1 nguồn reset chậm chưa rõ
  (không phải charger wdog, không modem SSR, không thermal).
- Vendor driver TỰ SIGKILL process khi fault (bắt tại trận qua ftrace signal_generate:
  sender chính phoc qua tgkill SI_TKILL; driver import raise@LIBC; kernel kgsl không giết).
- LD_PRELOAD không chặn được (glibc raise() gọi syscall trực tiếp); ptrace cũng không (SIGKILL).
- `nosuicide` (seccomp chặn tgkill-SIGKILL, test EPERM pass): process SỐNG qua fault,
  red client chạy hết 200–300 frames, KHÔNG reset — spiral kill-restart-watchdog là nguồn reset chính!
- Screenshot vẫn đen sau sống sót (ctx chết, draws bị skip) — sống ≠ hình.
- LLC slice on/off: không đổi. Ép clocks: không đổi. Buffer 1/2/3/8: chết y hệt.
- Damage tắt: chết ở ts cao (4162/8321) thay vì ts 2 — nhưng không cứu được.
- Stock DTB (boot.img V12.5.7) vs rec-picasso.dtb: phần GPU GIỐNG HỆT → loại DT.
- Custom dtbo vs stock: chỉ khác panel/FOD cosmetics (smart-fps, dims, HBM cmds) → loại dtbo.
- Kernel trio Oct-12 (secure-bypass/amsbc/IRQ) + kgsl_events #if0: TRUNG TÍNH với fault.
  Phát hiện: kernel #42 đang chạy build từ source TRƯỚC trio (object cũ hơn commit) — trio
  chưa từng được test cho tới build #44/#45/#46 tay.
- kgsl_events #if0 gây event storm (load 45): REVERT ngay, nguy hiểm.
- nosuicide là drop-in permanent (70-nosuicide.conf) — session sống qua fault, hết spiral reset.
- Mesa-CPU đỏ chuẩn → kernel/memory vô tội; bệnh khoanh vào vendor-GPU path.

## Bổ sung: thử blob Adreno MIUI 13 (đang tiến hành)
- Đang tải `miui_PICASSO_V13.0.5.0.SGICNXM` (4.6GB, Android 12, 2022-11) từ bigota.d.miui.com
  (aria2c 16 luồng; wget 1 luồng bị throttle ~17KB/s).
- Kế hoạch: bung vendor.new.dat.br → vendor.img → lấy libEGL/GLESv2_adreno 2022,
  backup bản cũ, swap file, test egltest3 (triangle). Revert được ngay, không flash.
- Mirror dự phòng: bkt-sgp (Alibaba SG), bn.d.miui, cdnorg, hugeota.
