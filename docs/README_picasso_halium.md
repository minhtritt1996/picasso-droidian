# 📱 HƯỚNG DẪN CHI TIẾT PORT & CÀI ĐẶT DROIDIAN (HALIUM 11) CHO REDMI K30 5G (PICASSO)

Tài liệu này được biên soạn dựa trên nghiên cứu và kiểm tra chéo các thông số kỹ thuật thực tế cho thiết bị Xiaomi Redmi K30 5G (mã: `picasso`, SoC: Qualcomm Snapdragon 765G `sm7250 / lito`).

---

## 📑 MỤC LỤC
1. [Tổng quan & Cảnh báo an toàn](#1-tổng-quan--cảnh-báo-an-toàn)
2. [Bước 0: Kiểm tra Anti-Rollback (Tránh Brick)](#2-bước-0-kiểm-tra-anti-rollback-tránh-brick)
3. [Bước 1: Sao lưu các phân vùng sống còn (Persist, EFS, Modem)](#3-bước-1-sao-lưu-các-phân-vùng-sống-còn)
4. [Bước 2: Hạ cấp về Firmware Android 11 Chuẩn](#4-bước-2-hạ-cấp-về-firmware-android-11-chuẩn)
5. [Bước 3: Biên dịch `halium-boot-picasso.img`](#5-bước-3-biên-dịch-halium-boot-picassoimg)
   - [Cách A: Sử dụng GitHub Actions (Khuyên dùng)](#cách-a-sử-dụng-github-actions-khuyên-dùng)
   - [Cách B: Biên dịch trực tiếp trên máy Linux](#cách-b-biên-dịch-trực-tiếp-trên-máy-linux)
6. [Bước 4: Cài đặt OrangeFox Recovery](#6-bước-4-cài-đặt-orangefox-recovery)
7. [Bước 5: Flash Halium Boot & Droidian Rootfs](#7-bước-5-flash-halium-boot--droidian-rootfs)
8. [Bước 6: Khởi động lần đầu & Gỡ lỗi qua Telnet](#8-bước-6-khởi-động-lần-đầu--gỡ-lỗi-qua-telnet)

---

## 1. TỔNG QUAN & CẢNH BÁO AN TOÀN

> [!CAUTION]
> **QUAN TRỌNG:**
> - Máy của bạn hiện đang chạy **Android 16 Custom ROM**.
> - Để Halium 11 hoạt động, vendor bắt buộc phải là **Android 11 (MIUI 12.5)**.
> - Việc hạ cấp giữa các phiên bản Android lớn của Xiaomi tiềm ẩn rủi ro **Anti-Rollback (ARB)**. Nếu vi phạm ARB, máy sẽ rơi vào trạng thái Hard Brick (chỉ nhận EDL 9008, cần tài khoản Authorized Mi Account để cứu).
> - **Tuyệt đối KHÔNG chọn tùy chọn "Clean all and lock" khi dùng MiFlash Tool.** Luôn chọn "Clean all".

---

## 2. BƯỚC 0: KIỂM TRA ANTI-ROLLBACK (TRÁNH BRICK)

Trước khi tải hoặc flash bất kỳ bản ROM MIUI cũ nào:

1. Đưa điện thoại về chế độ **Fastboot** (Tắt máy, nhấn giữ `Volume Down + Nguồn`).
2. Kết nối cáp USB với máy tính.
3. Chạy script kiểm tra tự động đi kèm:
   ```bash
   ./check_arb_picasso.sh
   ```
   Hoặc tự chạy lệnh:
   ```bash
   fastboot getvar anti
   ```
4. **Đọc kết quả:**
   - Nếu trả về trống, hoặc `anti: ` không có số: Máy chưa bị khoá ARB nghiêm ngặt.
   - Nếu trả về số (ví dụ: `anti: 1` hoặc `anti: 2`): Ghi nhớ số này (`Device ARB`).
5. **So sánh với ROM mục tiêu (`V12.5.7.0.RGICNXM`):**
   - Mở file `flash_all.sh` trong thư mục ROM fastboot Android 11.
   - Tìm biến `CURRENT_ANTI_VER`:
     ```bash
     grep -i "CURRENT_ANTI_VER" flash_all.sh
     ```
   - **Quy tắc vàng:** `Device ARB <= ROM CURRENT_ANTI_VER` → **AN TOÀN**.
   - Nếu `Device ARB > ROM CURRENT_ANTI_VER` → **DỪNG LẠI NGAY LẬP TỨC!** Không flash bản ROM đó.

---

## 3. BƯỚC 1: SAO LƯU CÁC PHÂN VÙNG SỐNG CÒN

Phân vùng `persist` chứa hiệu chuẩn cảm biến (vân tay, tiệm cận), `efs` chứa số IMEI và cấu hình sóng mạng.

### Cách sao lưu qua Recovery (OrangeFox/TWRP):
1. Vào Recovery → chọn mục **Backup**.
2. Đánh dấu chọn: **EFS**, **Modem**, và **Persist**.
3. Quẹt để sao lưu và chép file backup sang máy tính.

### Cách sao lưu qua lệnh ADB (yêu cầu máy đã Root):
```bash
adb shell su -c "dd if=/dev/block/bootdevice/by-name/persist of=/sdcard/persist.img"
adb shell su -c "dd if=/dev/block/bootdevice/by-name/modem of=/sdcard/modem.img"
adb shell su -c "dd if=/dev/block/bootdevice/by-name/efs of=/sdcard/efs.img"

adb pull /sdcard/persist.img ./backup_persist.img
adb pull /sdcard/modem.img ./backup_modem.img
adb pull /sdcard/efs.img ./backup_efs.img
```

---

## 4. BƯỚC 2: HẠ CẤP VỀ FIRMWARE ANDROID 11 CHUẨN

- Tải bản Full Fastboot ROM:
  - Tên file: `picasso_images_V12.5.7.0.RGICNXM_20211025.0000.00_11.0_cn_bcecc3ea11.tgz`
  - Khu vực: China Stable (Android 11)
  - MD5: `bcecc3ea1100f7088b28d4d501d40b57`
- Giải nén file:
  ```bash
  tar -xzf picasso_images_V12.5.7.0.RGICNXM_*.tgz
  cd picasso_images_V12.5.7.0.RGICNXM_*
  ```
- Flash:
  - **Trên Linux:** Chạy `./flash_all.sh` (Tuyệt đối không dùng `flash_all_lock.sh`).
  - **Trên Windows:** Dùng MiFlash Tool, chọn đường dẫn thư mục ROM, ở góc dưới chọn **Clean all** và ấn **Flash**.
- Sau khi khởi động lên MIUI 12.5 thành công, kiểm tra Wi-Fi, SIM sóng hoạt động bình thường trước khi tiếp tục.

---

## 5. BƯỚC 3: BIÊN DỊCH `HALIUM-BOOT-PICASSO.IMG`

Thông số kỹ thuật chuẩn của Picasso (Đã xác nhận):
- **Base:** `0x00000000`
- **Page size:** `4096`
- **Header Version:** `2`
- **Kernel Offset:** `0x00008000`
- **Ramdisk Offset:** `0x01000000`
- **Tags Offset:** `0x00000100`
- **DTB Offset:** `0x01f00000`
- **Cmdline:** `console=ttyMSM0,115200n8 earlycon=msm_geni_serial,0x4a90000 androidboot.hardware=qcom androidboot.console=ttyMSM0 androidboot.memcg=1 lpm_levels.sleep_disabled=1 video=vfb:640x400,bpp=32,memsize=3072000 msm_rtb.filter=0x237 service_locator.enable=1 swiotlb=2048 androidboot.usbcontroller=a600000.dwc3 loop.max_part=7 androidboot.usbconfigfs=true androidboot.selinux=permissive`

### Cách A: Sử dụng GitHub Actions (Khuyên dùng)
1. Tạo một repository mới trên GitHub (Private hoặc Public).
2. Tạo thư mục `.github/workflows/` và đưa file [`github_workflow_picasso_v2.yml`](file:///home/tritm/droidian/github_workflow_picasso_v2.yml) vào đổi tên thành `build.yml`.
3. Vào tab **Actions** trên GitHub repository → Chọn workflow **Build Halium Boot Image for Redmi K30 5G** → Bấm **Run workflow**.
4. Quá trình biên dịch trên đám mây mất khoảng 10-15 phút. Khi hoàn tất, tải artifact `halium-boot-picasso.zip` về máy và giải nén lấy `halium-boot-picasso.img`.

### Cách B: Biên dịch trực tiếp trên máy Linux
Sử dụng script đã được chuẩn bị sẵn:
```bash
cd /home/tritm/droidian
./build_halium_picasso.sh
```
File kết quả sẽ nằm tại: `output/halium-boot-picasso.img`.

---

## 6. BƯỚC 4: CÀI ĐẶT ORANGEFOX RECOVERY

Vì Picasso sử dụng cấu trúc phân vùng động (**Dynamic Partitions - super partition**), bạn cần OrangeFox Recovery hỗ trợ phân vùng động cho Android 11.

1. Tải bản OrangeFox mới nhất dành cho Picasso (tối thiểu R11.3 trở lên).
2. Flash recovery qua fastboot:
   ```bash
   fastboot flash recovery orangefox-picasso.img
   fastboot reboot recovery
   ```

---

## 7. BƯỚC 5: FLASH HALIUM BOOT & DROIDIAN ROOTFS

### 1. Tải Droidian Rootfs mới nhất
Truy cập trang releases chính thức:
👉 [Droidian Images Releases](https://github.com/droidian-images/droidian/releases)
Tải file rootfs dạng `.tar.xz` hoặc `.zip` dành cho kiến trúc `arm64`.
*(Lưu ý: Không tải các gói cũ `api28gsi` vì đã ngừng phát triển).*

### 2. Flash Halium Boot
Đưa máy về Fastboot:
```bash
fastboot flash boot halium-boot-picasso.img
fastboot reboot recovery
```

### 3. Cài đặt trong OrangeFox Recovery:
1. Vào **Wipe** → chọn **Format Data** (gõ `yes` để xoá sạch mã hoá data của Android cũ).
2. Vào **Mount** → kiểm tra phân vùng `/data` và `/system` có thể mount bình thường.
3. Chép file rootfs Droidian vào máy:
   ```bash
   adb push droidian-rootfs-*.zip /sdcard/
   ```
4. Trên OrangeFox, chọn **Install** → chọn file zip rootfs Droidian và quẹt để flash.
5. Sau khi flash xong, ấn **Reboot System**.

---

## 8. BƯỚC 6: KHỞI ĐỘNG LẦN ĐẦU & GỠ LỖI QUA TELNET

- Lần đầu khởi động sẽ mất khoảng 2-3 phút để tạo swap và mở rộng hệ điều hành.
- Giao diện người dùng mặc định: **Phosh (Wayland shell)**.
  - Tài khoản mặc định: `droidian`
  - Mật khẩu mặc định: `1234`

### 🛠️ Gỡ lỗi nếu không lên màn hình (Màn hình đen):
Nếu máy không lên màn hình hoặc treo logo, Halium Ramdisk sẽ tự động kích hoạt card mạng ảo USB (RNDIS gadget):
1. Cắm cáp USB với máy tính Linux.
2. Máy tính sẽ nhận card mạng ảo với dải IP `192.168.2.x`.
3. Kết nối vào điện thoại qua Telnet:
   ```bash
   telnet 192.168.2.15
   ```
4. Xem log hạt nhân để tìm nguyên nhân:
   ```bash
   dmesg -w
   journalctl -b
   ```
   - Nếu log báo lỗi panel / display: Cần kiểm tra lại file DTB được nhúng vào boot.img.
   - Nếu log báo cgroup / namespace: Kiểm tra lại các kernel config.
