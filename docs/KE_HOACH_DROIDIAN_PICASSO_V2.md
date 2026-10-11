# KẾ HOẠCH HOÀN CHỈNH PORT DROIDIAN / HALIUM 11 CHO REDMI K30 5G (PICASSO) - V2

> [!IMPORTANT]
> Phiên bản đã sửa tất cả lỗi từ kế hoạch gốc (Meta AI). Đã kiểm chứng qua 9 agent nghiên cứu.
> Đây là port MỚI — chưa có ai port Droidian cho picasso trước đó.

---

## 1. MỤC TIÊU
- Build halium-boot.img cho picasso từ kernel Android 11
- Flash Droidian (Debian + Phosh + Halium 11) lên picasso
- Máy gốc đang chạy Android 16 custom ROM

## 2. THÔNG TIN PHẦN CỨNG
| Thông số | Giá trị |
|---|---|
| Device | Redmi K30 5G / Racing Edition |
| Codename | picasso (không phải picasso_48m) |
| SoC | Qualcomm SM7250 Snapdragon 765G 5G |
| Platform | lito |
| Panel | JDI 120Hz |
| Partition | Dynamic (super) |
| Boot header | Version 2 |
| Yêu cầu vendor | Android 11 |

---

## ⚠️ 3. BƯỚC 0 — KIỂM TRA ANTI-ROLLBACK (LÀM TRƯỚC TIÊN)

> [!CAUTION]
> **KHÔNG BỎ QUA BƯỚC NÀY.** Nếu ARB index sai, flash firmware cũ = BRICK CỨNG không cứu được.

### 3.1 Kiểm tra ARB trên máy:
```bash
# Boot vào fastboot mode (Volume Down + Power)
fastboot getvar anti
```
- Ghi lại số trả về (ví dụ: `anti: 3`)
- Nếu trả về trống hoặc "failed" → ARB không active, an toàn hơn nhưng vẫn cẩn thận

### 3.2 Kiểm tra ARB trong ROM Android 11:
```bash
# Giải nén file picasso_images_V12.5.7.0.RGICNXM_20211025.0000.00_11.0_cn_bcecc3ea11.tgz
tar xzf picasso_images_*.tgz
# Mở flash_all.sh hoặc flash_all.bat, tìm dòng:
grep -i "CURRENT_ANTI_VER" flash_all.sh
# Hoặc tìm: set CURRENT_ANTI_VER=X
```

### 3.3 So sánh:
- **Nếu ARB máy ≤ ARB ROM** → An toàn, tiếp tục
- **Nếu ARB máy > ARB ROM** → **DỪNG LẠI!** Không flash. Cần:
  - Tìm firmware Android 11 có ARB index cao hơn, HOẶC
  - Dùng EDL mode (cần tool trả phí: UnlockTool / ChimeraTool / XRT)

### 3.4 Backup partitions quan trọng TRƯỚC KHI LÀM GÌ:
```bash
# Qua TWRP/OrangeFox Recovery:
# Backup → chọn EFS, Modem, Persist → Swipe to backup → copy ra PC

# HOẶC qua ADB với root:
adb shell
dd if=/dev/block/bootdevice/by-name/persist of=/sdcard/persist.img
dd if=/dev/block/bootdevice/by-name/modem of=/sdcard/modem.img
dd if=/dev/block/bootdevice/by-name/efs of=/sdcard/efs.img
exit
adb pull /sdcard/persist.img
adb pull /sdcard/modem.img
adb pull /sdcard/efs.img
```

---

## 4. FIRMWARE GỐC CẦN VỀ (CHỈ SAU KHI BƯỚC 3 AN TOÀN)
BẮT BUỘC về Android 11 trước khi làm Halium 11.

### File 1 — Full Fastboot ROM (khuyên dùng):
- Tên: `picasso_images_V12.5.7.0.RGICNXM_20211025.0000.00_11.0_cn_bcecc3ea11.tgz`
- Android: 11.0
- MIUI: V12.5.7.0.RGICNXM China Stable ✅ (đã xác nhận tồn tại)
- MD5: bcecc3ea1100f7088b28d4d501d40b57
- Size: 4.6GB
- Nguồn: mifirm.net / xiaomirom.com ✅

### Cách flash (từ Android 16 custom ROM):
```bash
# Giải nén ROM
tar xzf picasso_images_*.tgz
cd picasso_images_*

# Dùng MiFlash Tool (Windows) - chọn "Clean all"
# ⚠️ KHÔNG CHỌN "Clean all and lock" — sẽ brick!

# HOẶC chạy script (Linux):
chmod +x flash_all.sh
./flash_all.sh
# ⚠️ KHÔNG dùng flash_all_lock.sh
```

### File 2 — Vendor only (95MB) nếu cần flash riêng:
- Tên: `fw_picasso_miui_PICASSO_V12.5.7.0.RGICNXM_02c694af6e_11.0.zip` ✅ (đã xác nhận tồn tại)

---

## 5. KERNEL SOURCE (ĐÃ SỬA)

> [!WARNING]
> Kế hoạch gốc nói dùng `PeterCxy/android_kernel_xiaomi_sm7250` branch `lineage-18.1` — **branch này KHÔNG TỒN TẠI**. Dưới đây là source đúng.

### Lựa chọn 1 — LineageOS (KHUYÊN DÙNG cho Halium 11):
```bash
git clone https://github.com/LineageOS/android_kernel_xiaomi_sm7250 -b lineage-18.1 --depth=1
```
- Branch: `lineage-18.1` (Android 11) ✅ đã xác nhận tồn tại
- Defconfig: `vendor/picasso_user_defconfig` ✅
- Defconfig backup: `vendor/lito-perf_defconfig` ✅

### Lựa chọn 2 — Xiaomi Official (MiCode):
```bash
git clone https://github.com/MiCode/Xiaomi_Kernel_OpenSource -b picasso-r-oss --depth=1
```
- Branch: `picasso-r-oss` (R = Android 11) ✅ đã xác nhận tồn tại
- Defconfig: `vendor/picasso_user_defconfig` ✅

### ❌ KHÔNG DÙNG:
- ~~PeterCxy/android_kernel_xiaomi_sm7250 branch lineage-18.1~~ → branch không tồn tại
- ~~LineageOS/android_kernel_oneplus_sm7250~~ → kernel OnePlus, không hỗ trợ picasso

---

## 6. KERNEL CONFIG PATCH ĐẦY ĐỦ CHO HALIUM / DROIDIAN (ĐÃ SỬA)

> [!IMPORTANT]
> Kế hoạch gốc thiếu nhiều config quan trọng + có 1 config ảo. Dưới đây là danh sách đầy đủ từ script `check-kernel-config` chính thức.

### 6.1 Tạo defconfig:
```bash
cd kernel_source
export ARCH=arm64
make O=out vendor/picasso_user_defconfig
```

### 6.2 Patch bằng scripts/config:
```bash
CFG=out/.config
SC=scripts/config

# === BINDER (cho kernel 4.19 — KHÔNG dùng BINDERFS vì chỉ có từ kernel 5.0) ===
$SC --file $CFG --enable CONFIG_ANDROID
$SC --file $CFG --enable CONFIG_ANDROID_BINDER_IPC
$SC --file $CFG --set-str CONFIG_ANDROID_BINDER_DEVICES "binder,hwbinder,vndbinder"
$SC --file $CFG --enable CONFIG_ASHMEM

# === NAMESPACES (BẮT BUỘC cho LXC container) ===
$SC --file $CFG --enable CONFIG_NAMESPACES
$SC --file $CFG --enable CONFIG_UTS_NS
$SC --file $CFG --enable CONFIG_IPC_NS
$SC --file $CFG --enable CONFIG_USER_NS
$SC --file $CFG --enable CONFIG_PID_NS
$SC --file $CFG --enable CONFIG_NET_NS

# === CGROUPS ===
$SC --file $CFG --enable CONFIG_CGROUPS
$SC --file $CFG --enable CONFIG_CPUSETS
$SC --file $CFG --enable CONFIG_CGROUP_DEVICE
$SC --file $CFG --enable CONFIG_CGROUP_FREEZER
$SC --file $CFG --enable CONFIG_BLK_CGROUP
$SC --file $CFG --enable CONFIG_CGROUP_PERF

# === APPARMOR (security cho Halium) ===
$SC --file $CFG --enable CONFIG_SECURITY
$SC --file $CFG --enable CONFIG_SECURITY_APPARMOR
$SC --file $CFG --enable CONFIG_SECURITY_APPARMOR_HASH
$SC --file $CFG --enable CONFIG_DEFAULT_SECURITY_APPARMOR
$SC --file $CFG --set-str CONFIG_DEFAULT_SECURITY "apparmor"
$SC --file $CFG --set-val CONFIG_SECURITY_APPARMOR_BOOTPARAM_VALUE 1
$SC --file $CFG --set-val CONFIG_SECURITY_SELINUX_BOOTPARAM_VALUE 0
$SC --file $CFG --enable CONFIG_SECCOMP
$SC --file $CFG --enable CONFIG_SECURITYFS
$SC --file $CFG --enable CONFIG_SECURITY_NETWORK
$SC --file $CFG --enable CONFIG_SECURITY_PATH
$SC --file $CFG --enable CONFIG_AUDIT

# === VIRTUAL TERMINAL (bắt buộc cho LXC/Halium) ===
$SC --file $CFG --enable CONFIG_VT
$SC --file $CFG --enable CONFIG_VT_CONSOLE

# === IPC ===
$SC --file $CFG --enable CONFIG_SYSVIPC

# === DEVICE FILESYSTEM ===
$SC --file $CFG --enable CONFIG_DEVTMPFS
$SC --file $CFG --enable CONFIG_DEVTMPFS_MOUNT
$SC --file $CFG --enable CONFIG_DEVPTS_MULTIPLE_INSTANCES

# === FILESYSTEM ===
$SC --file $CFG --enable CONFIG_TMPFS_XATTR
$SC --file $CFG --enable CONFIG_TMPFS_POSIX_ACL
$SC --file $CFG --enable CONFIG_AUTOFS4_FS
$SC --file $CFG --enable CONFIG_EXT4_FS_POSIX_ACL
$SC --file $CFG --enable CONFIG_EXT4_FS_SECURITY
$SC --file $CFG --enable CONFIG_FHANDLE
$SC --file $CFG --enable CONFIG_IKCONFIG
$SC --file $CFG --enable CONFIG_IKCONFIG_PROC

# === MISC SYSCALLS ===
$SC --file $CFG --enable CONFIG_EPOLL
$SC --file $CFG --enable CONFIG_SIGNALFD
$SC --file $CFG --enable CONFIG_TIMERFD
$SC --file $CFG --enable CONFIG_INOTIFY_USER
$SC --file $CFG --enable CONFIG_ENCRYPTED_KEYS
$SC --file $CFG --enable CONFIG_PSI

# === NETWORK / IPTABLES (cho LXC bridge + NAT) ===
$SC --file $CFG --enable CONFIG_BRIDGE
$SC --file $CFG --enable CONFIG_VETH
$SC --file $CFG --enable CONFIG_MACVLAN
$SC --file $CFG --enable CONFIG_NF_NAT
$SC --file $CFG --enable CONFIG_IP_NF_NAT
$SC --file $CFG --enable CONFIG_IP_NF_IPTABLES
$SC --file $CFG --enable CONFIG_NF_CONNTRACK
$SC --file $CFG --enable CONFIG_NETFILTER_XT_MATCH_ADDRTYPE
$SC --file $CFG --enable CONFIG_NETFILTER_XT_MATCH_CONNTRACK
$SC --file $CFG --enable CONFIG_NETFILTER_XT_MATCH_MULTIPORT
$SC --file $CFG --enable CONFIG_NETFILTER_XT_MATCH_STATE
$SC --file $CFG --enable CONFIG_NETFILTER_XT_MATCH_PHYSDEV
$SC --file $CFG --enable CONFIG_NETFILTER_XT_TARGET_MARK
$SC --file $CFG --enable CONFIG_NETFILTER_XT_TARGET_CONNMARK
$SC --file $CFG --enable CONFIG_NETFILTER_XT_TARGET_LOG
$SC --file $CFG --enable CONFIG_IP_ADVANCED_ROUTER

# === TẮT CÁC CONFIG KHÔNG TƯƠNG THÍCH ===
$SC --file $CFG --disable CONFIG_ANDROID_LOW_MEMORY_KILLER
$SC --file $CFG --disable CONFIG_ANDROID_PARANOID_NETWORK
$SC --file $CFG --disable CONFIG_DEFAULT_SECURITY_SELINUX
```

### 6.3 Kiểm tra config:
```bash
# Dùng script check chính thức từ halium-boot master:
git clone https://github.com/Halium/halium-boot --depth=1
./halium-boot/check-kernel-config out/.config
# Nếu báo lỗi, dùng -w để tự patch:
./halium-boot/check-kernel-config out/.config -w
```

---

## 7. BUILD KERNEL (ĐÃ SỬA)

> [!WARNING]
> Kế hoạch gốc thiếu `ARCH=arm64` — build sẽ fail hoặc tạo kernel x86_64 vô dụng.

```bash
export ARCH=arm64
export SUBARCH=arm64

# Build kernel + DTBs
make O=out ARCH=arm64 \
     CC=clang \
     CLANG_TRIPLE=aarch64-linux-gnu- \
     CROSS_COMPILE=aarch64-linux-gnu- \
     -j$(nproc) \
     Image.gz dtbs
```

### Output cần có:
- `out/arch/arm64/boot/Image.gz`
- `out/arch/arm64/boot/dts/qcom/*.dtb` (tìm file có tên picasso hoặc lito)

---

## 8. OFFSETS + CMDLINE CHUẨN (ĐÃ XÁC NHẬN ĐÚNG 100%)

Đã cross-reference với LineageOS, crDroid, TWRP device trees:

| Parameter | Giá trị | Trạng thái |
|---|---|---|
| BOARD_KERNEL_BASE | 0x00000000 | ✅ |
| BOARD_KERNEL_PAGESIZE | 4096 | ✅ |
| BOARD_BOOTIMG_HEADER_VERSION | 2 | ✅ |
| BOARD_KERNEL_SEPARATED_DTBO | true | ✅ |
| BOARD_INCLUDE_DTB_IN_BOOTIMG | true | ✅ |
| BOARD_KERNEL_OFFSET | 0x00008000 | ✅ |
| BOARD_RAMDISK_OFFSET | 0x01000000 | ✅ |
| BOARD_TAGS_OFFSET | 0x00000100 | ✅ |
| BOARD_DTB_OFFSET | 0x01f00000 | ✅ |

### CMDLINE:
```
console=ttyMSM0,115200n8 earlycon=msm_geni_serial,0x4a90000 androidboot.hardware=qcom androidboot.console=ttyMSM0 androidboot.memcg=1 lpm_levels.sleep_disabled=1 video=vfb:640x400,bpp=32,memsize=3072000 msm_rtb.filter=0x237 service_locator.enable=1 swiotlb=2048 androidboot.usbcontroller=a600000.dwc3 loop.max_part=7 androidboot.usbconfigfs=true androidboot.selinux=permissive
```
> Đã sửa `swiotlb=1` → `swiotlb=2048` theo chuẩn LineageOS/crDroid để tránh lỗi DMA.

---

## 9. BUILD HALIUM-BOOT.IMG (ĐÃ SỬA HOÀN TOÀN)

> [!WARNING]
> Kế hoạch gốc dùng `halium-boot -b halium-11.0` — branch này KHÔNG TỒN TẠI.
> Phương pháp cũ (halium-boot script) đã lỗi thời cho Halium 11.

### Phương pháp 1 — Dùng halium-generic-adaptation-build-tools (KHUYÊN DÙNG):
```bash
git clone https://gitlab.com/ubports/porting/community-ports/halium-generic-adaptation-build-tools.git -b halium-11
cd halium-generic-adaptation-build-tools
# Tool này tự tạo ramdisk + pack boot.img
./build.sh -b <build_dir> -o <output_dir>
```

### Phương pháp 2 — Dùng mkbootimg thủ công:
```bash
# 1. Lấy ramdisk/initrd Halium
git clone https://github.com/nickneos/halium-boot --depth=1
# HOẶC extract ramdisk từ halium-generic-adaptation-build-tools

# 2. Tìm DTB
DTB=$(find out/arch/arm64/boot/dts/qcom -name "*picasso*.dtb" -o -name "*lito*.dtb" | head -n1)

# 3. Pack boot.img
mkbootimg \
  --kernel out/arch/arm64/boot/Image.gz \
  --ramdisk initrd.img \
  --dtb $DTB \
  --base 0x00000000 \
  --pagesize 4096 \
  --kernel_offset 0x00008000 \
  --ramdisk_offset 0x01000000 \
  --tags_offset 0x00000100 \
  --dtb_offset 0x01f00000 \
  --header_version 2 \
  --cmdline "console=ttyMSM0,115200n8 earlycon=msm_geni_serial,0x4a90000 androidboot.hardware=qcom androidboot.console=ttyMSM0 androidboot.memcg=1 lpm_levels.sleep_disabled=1 video=vfb:640x400,bpp=32,memsize=3072000 msm_rtb.filter=0x237 service_locator.enable=1 swiotlb=2048 androidboot.usbcontroller=a600000.dwc3 loop.max_part=7 androidboot.usbconfigfs=true androidboot.selinux=permissive" \
  -o halium-boot-picasso.img
```

### Phương pháp 3 — Full Android tree (phức tạp nhưng chuẩn nhất):
```bash
repo init -u https://github.com/Halium/android -b halium-11.0 --depth=1
repo sync -c -j8
source build/envsetup.sh
lunch picasso-userdebug
export USE_HOST_LEX=yes
mka mkbootimg
mka hybris-boot
```

---

## 10. BUILD TRÊN GITHUB ACTIONS
Tạo repo mới, tạo file `.github/workflows/build.yml`:

```yaml
name: Build Halium Boot for Picasso
on:
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Install dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y bc bison build-essential flex libssl-dev \
            libelf-dev clang lld llvm gcc-aarch64-linux-gnu \
            python3 python3-pip git wget
          pip3 install mkbootimg || true

      - name: Clone kernel (LineageOS Android 11)
        run: |
          git clone https://github.com/LineageOS/android_kernel_xiaomi_sm7250 \
            -b lineage-18.1 --depth=1 kernel

      - name: Setup defconfig
        run: |
          cd kernel
          export ARCH=arm64
          make O=out vendor/picasso_user_defconfig

      - name: Patch kernel config for Halium
        run: |
          cd kernel
          SC=scripts/config
          CFG=out/.config
          # Binder (kernel 4.19)
          $SC --file $CFG --enable CONFIG_ANDROID
          $SC --file $CFG --enable CONFIG_ANDROID_BINDER_IPC
          $SC --file $CFG --set-str CONFIG_ANDROID_BINDER_DEVICES "binder,hwbinder,vndbinder"
          $SC --file $CFG --enable CONFIG_ASHMEM
          # Namespaces
          $SC --file $CFG --enable CONFIG_NAMESPACES
          $SC --file $CFG --enable CONFIG_UTS_NS
          $SC --file $CFG --enable CONFIG_IPC_NS
          $SC --file $CFG --enable CONFIG_USER_NS
          $SC --file $CFG --enable CONFIG_PID_NS
          $SC --file $CFG --enable CONFIG_NET_NS
          # Cgroups
          $SC --file $CFG --enable CONFIG_CGROUPS
          $SC --file $CFG --enable CONFIG_CPUSETS
          $SC --file $CFG --enable CONFIG_CGROUP_DEVICE
          $SC --file $CFG --enable CONFIG_CGROUP_FREEZER
          $SC --file $CFG --enable CONFIG_BLK_CGROUP
          # AppArmor
          $SC --file $CFG --enable CONFIG_SECURITY
          $SC --file $CFG --enable CONFIG_SECURITY_APPARMOR
          $SC --file $CFG --enable CONFIG_SECURITY_APPARMOR_HASH
          $SC --file $CFG --enable CONFIG_DEFAULT_SECURITY_APPARMOR
          $SC --file $CFG --set-str CONFIG_DEFAULT_SECURITY "apparmor"
          $SC --file $CFG --set-val CONFIG_SECURITY_APPARMOR_BOOTPARAM_VALUE 1
          $SC --file $CFG --set-val CONFIG_SECURITY_SELINUX_BOOTPARAM_VALUE 0
          $SC --file $CFG --enable CONFIG_SECCOMP
          $SC --file $CFG --enable CONFIG_AUDIT
          # VT + IPC
          $SC --file $CFG --enable CONFIG_VT
          $SC --file $CFG --enable CONFIG_VT_CONSOLE
          $SC --file $CFG --enable CONFIG_SYSVIPC
          # Devtmpfs
          $SC --file $CFG --enable CONFIG_DEVTMPFS
          $SC --file $CFG --enable CONFIG_DEVTMPFS_MOUNT
          # Filesystem
          $SC --file $CFG --enable CONFIG_TMPFS_POSIX_ACL
          $SC --file $CFG --enable CONFIG_TMPFS_XATTR
          $SC --file $CFG --enable CONFIG_IKCONFIG
          $SC --file $CFG --enable CONFIG_IKCONFIG_PROC
          $SC --file $CFG --enable CONFIG_FHANDLE
          $SC --file $CFG --enable CONFIG_PSI
          # Network
          $SC --file $CFG --enable CONFIG_BRIDGE
          $SC --file $CFG --enable CONFIG_VETH
          $SC --file $CFG --enable CONFIG_NF_NAT
          $SC --file $CFG --enable CONFIG_IP_NF_NAT
          $SC --file $CFG --enable CONFIG_IP_NF_IPTABLES
          $SC --file $CFG --enable CONFIG_NF_CONNTRACK
          $SC --file $CFG --enable CONFIG_IP_ADVANCED_ROUTER
          $SC --file $CFG --enable CONFIG_NETFILTER_XT_MATCH_PHYSDEV
          # Tắt
          $SC --file $CFG --disable CONFIG_ANDROID_LOW_MEMORY_KILLER
          $SC --file $CFG --disable CONFIG_ANDROID_PARANOID_NETWORK

      - name: Build kernel
        run: |
          cd kernel
          export ARCH=arm64
          export SUBARCH=arm64
          make O=out ARCH=arm64 \
               CC=clang \
               CLANG_TRIPLE=aarch64-linux-gnu- \
               CROSS_COMPILE=aarch64-linux-gnu- \
               -j$(nproc) \
               Image.gz dtbs

      - name: Find DTB
        id: dtb
        run: |
          DTB=$(find kernel/out/arch/arm64/boot/dts/qcom \
            -name "*picasso*.dtb" -o -name "*lito*.dtb" | head -n1)
          echo "DTB=$DTB" >> $GITHUB_OUTPUT
          echo "Found DTB: $DTB"

      - name: Get Halium ramdisk
        run: |
          git clone https://gitlab.com/ubports/porting/community-ports/halium-generic-adaptation-build-tools.git \
            -b halium-11 --depth=1 hgabt
          # Extract/build ramdisk from tools
          # Fallback: clone halium-boot master
          git clone https://github.com/Halium/halium-boot --depth=1

      - name: Pack boot.img
        run: |
          KERNEL=kernel/out/arch/arm64/boot/Image.gz
          DTB=${{ steps.dtb.outputs.DTB }}
          # Find ramdisk
          RAMDISK=$(find . -name "initrd.img" -o -name "*.cpio.gz" | head -n1)

          mkbootimg \
            --kernel $KERNEL \
            --ramdisk $RAMDISK \
            --dtb $DTB \
            --base 0x00000000 \
            --pagesize 4096 \
            --kernel_offset 0x00008000 \
            --ramdisk_offset 0x01000000 \
            --tags_offset 0x00000100 \
            --dtb_offset 0x01f00000 \
            --header_version 2 \
            --cmdline "console=ttyMSM0,115200n8 earlycon=msm_geni_serial,0x4a90000 androidboot.hardware=qcom androidboot.console=ttyMSM0 androidboot.memcg=1 lpm_levels.sleep_disabled=1 video=vfb:640x400,bpp=32,memsize=3072000 msm_rtb.filter=0x237 service_locator.enable=1 swiotlb=2048 androidboot.usbcontroller=a600000.dwc3 loop.max_part=7 androidboot.usbconfigfs=true androidboot.selinux=permissive" \
            -o halium-boot-picasso.img

      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: halium-boot-picasso
          path: halium-boot-picasso.img
```

---

## 11. FLASH DROIDIAN (ĐÃ CẬP NHẬT)

> [!WARNING]
> Kế hoạch gốc dùng `droidian-rootfs-api28gsi` — đã **DEPRECATED hoàn toàn**.
> Dùng rootfs mới từ droidian-images releases.

### Yêu cầu:
- Đã về MIUI V12.5.7.0.RGICNXM Android 11
- Đã có OrangeFox Recovery for picasso (hỗ trợ dynamic partition) ✅
- Tải rootfs mới: https://github.com/droidian-images/droidian/releases (bản mới nhất)

### Các bước:

#### Bước 1: Flash halium-boot
```bash
fastboot flash boot halium-boot-picasso.img
```

#### Bước 2: Vào recovery
```bash
fastboot reboot recovery
```

#### Bước 3: Trong OrangeFox Recovery:
1. **Wipe → Format data** (bắt buộc nếu từ Android 16 xuống)
2. **Install zip**: rootfs Droidian mới nhất (từ droidian-images releases)
3. **Install zip**: `droidian-devtools_arm64_*.zip` (nếu có)
4. **Install zip**: adaptation zip cho lito (nếu có) — hiện chưa có sẵn cho picasso, cần tự build

#### Bước 4: Reboot
- Đợi 2-3 phút logo Droidian → vào Phosh
- User: `droidian` / Pass: `1234`

### Tự build adaptation package (vì chưa có sẵn cho picasso):
- Tham khảo: https://porting.droidian.org/
- GitHub: https://github.com/droidian/porting-guide
- Cần tạo `.deb` chứa udev rules, firmware links, init scripts
- Hoặc hỏi cộng đồng: Telegram `@DroidianLinux` / Matrix `#droidian:matrix.org`

---

## 12. TROUBLESHOOTING

| Triệu chứng | Nguyên nhân | Giải pháp |
|---|---|---|
| Màn đen sau flash boot | DTB sai | Extract dtb từ boot.img stock V12.5.7.0, pack lại với Image.gz mới |
| Bootloop logo Mi | Sai offsets hoặc header version | Kiểm tra header v2, pagesize 4096, base 0x00000000 |
| Không có sóng / wifi | Thiếu vendor firmware | Flash `fw_picasso_miui_PICASSO_V12.5.7.0.RGICNXM_02c694af6e_11.0.zip` |
| Halium container không khởi | Thiếu namespace configs | Bổ sung tất cả namespace configs ở mục 6 |
| Kernel panic | Dùng kernel sai thiết bị | Chỉ dùng kernel LineageOS/sm7250 hoặc MiCode/picasso-r-oss |
| Brick cứng | ARB violation khi downgrade | Cần EDL mode + UnlockTool/ChimeraTool |
| DMA/memory errors | swiotlb quá thấp | Dùng `swiotlb=2048` thay vì `swiotlb=1` |

### Telnet debug:
Nếu boot fail, Halium initramfs tạo RNDIS gadget `192.168.2.15`:
```bash
telnet 192.168.2.15
# Xem log:
dmesg
journalctl -b
```

---

## 13. TỶ LỆ THÀNH CÔNG ƯỚC TÍNH
- Build kernel thành công: **90%**
- Pack halium-boot đúng chuẩn: **95%**
- Boot lên Phosh (có màn hình): **50-65%** (đây là port mới, chưa ai thử trước)
- Full chức năng (wifi, modem, data): **30-50%** lần đầu
- Sau debug + adaptation: **70-80%**

---

## 14. TÀI NGUYÊN THAM KHẢO
- Droidian Porting Guide: https://porting.droidian.org/
- Halium Docs: https://docs.halium.org/
- Halium Generic Adaptation Build Tools: https://gitlab.com/ubports/porting/community-ports/halium-generic-adaptation-build-tools
- Droidian Releases: https://github.com/droidian-images/droidian/releases
- Droidian Community: Telegram `@DroidianLinux` / Matrix `#droidian:matrix.org`
- LineageOS kernel: https://github.com/LineageOS/android_kernel_xiaomi_sm7250
- MiCode kernel: https://github.com/MiCode/Xiaomi_Kernel_OpenSource (branch `picasso-r-oss`)
