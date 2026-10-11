# KẾ HOẠCH CHI TIẾT PORT DROIDIAN / HALIUM 11 CHO REDMI K30 5G (PICASSO) - SM7250 LITO

## 1. MỤC TIÊU
- Build halium-boot.img cho picasso từ kernel Android 11
- Flash Droidian (Debian + Phosh + Halium 11) lên picasso
- Máy gốc đang chạy Android 16 custom ROM

## 2. THÔNG TIN PHẦN CỨNG
- Device: Redmi K30 5G / Racing Edition
- Codename: picasso (không phải picasso_48m)
- Chip: Qualcomm SM7250 Snapdragon 765G 5G (lito)
- Panel: JDI 120Hz
- Yêu cầu vendor: Android 11

## 3. FIRMWARE GỐC CẦN VỀ
BẮT BUỘC về Android 11 trước khi làm Halium 11.

File 1 - Full Fastboot ROM (khuyên dùng vì đang ở Android 16):
- Tên: picasso_images_V12.5.7.0.RGICNXM_20211025.0000.00_11.0_cn_bcecc3ea11.tgz
- Android: 11.0
- MIUI: V12.5.7.0.RGICNXM China Stable
- MD5: bcecc3ea1100f7088b28d4d501d40b57
- Size: 4.6GB
- Nguồn: mifirm.net ID 6080 / xiaomirom.com / Xiaomi official server
- Cách flash: giải nén -> chạy flash_all.sh (KHÔNG dùng flash_all_lock.sh) bằng MiFlash hoặc fastboot. Hoặc manual: fastboot flash tất cả partition.

File 2 - Vendor only (95MB) nếu không muốn flash full:
- Tên: fw_picasso_miui_PICASSO_V12.5.7.0.RGICNXM_02c694af6e_11.0.zip
- Android: 11.0
- Dùng để flash qua fastbootd hoặc OrangeFox khi cần giữ data.

Lưu ý: Backup persist partition trước khi downgrade: fastboot flash backup persist.img

## 4. KERNEL SOURCE
- Repo chính: https://github.com/PeterCxy/android_kernel_xiaomi_sm7250
- Branch: lineage-18.1 (Android 11 / Halium 11)
- Branch backup: LineageOS/android_kernel_oneplus_sm7250 branch lineage-21 (4.19.300) cũng dùng được nhưng ưu tiên PeterCxy vì có dtb picasso chuẩn.
- Defconfig: Thử theo thứ tự:
  1. arch/arm64/configs/vendor/picasso_defconfig
  2. arch/arm64/configs/picasso_defconfig
  3. arch/arm64/configs/vendor/lito-perf_defconfig (dùng chung cho cả họ lito)
- Compiler: clang + lld (kernel 4.19 hỗ trợ clang)
- CROSS_COMPILE: aarch64-linux-gnu-
- ARCH: arm64, SUBARCH: arm64

## 5. KERNEL CONFIG PATCH CHO HALIUM / DROIDIAN
Sau khi make defconfig, cần enable các config sau bằng scripts/config:

Bắt buộc Halium:
CONFIG_ANDROID=y
CONFIG_ANDROID_BINDERFS=y
CONFIG_ANDROID_BINDER_IPC=y
CONFIG_ASHMEM=y
CONFIG_SECURITY_APPARMOR=y
CONFIG_SECURITY_APPARMOR_BOOTPARAM_VALUE=1
CONFIG_SECURITY_APPARMOR_HASH=y
CONFIG_AUDIT=y
CONFIG_AUDIT_GENERIC=y
CONFIG_PSI=y
CONFIG_PSI_DEFAULT_DISABLED=y
CONFIG_NETFILTER_XT_MATCH_PHYSDEV=y
CONFIG_IP_NF_IPTABLES=y
CONFIG_NETFILTER_XT_TARGET_ADVROUTER=y

Thêm cho Droidian/Mobian:
CONFIG_TMPFS_POSIX_ACL=y
CONFIG_IKCONFIG=y
CONFIG_IKCONFIG_PROC=y
CONFIG_CGROUPS=y
CONFIG_CGROUP_FREEZER=y

Kiểm tra bằng script: halium-boot/check-kernel-config .config
Nếu script báo lỗi, fix bằng -w: ./halium-boot/check-kernel-config .config -w

## 6. BUILD KERNEL
export ARCH=arm64
export SUBARCH=arm64
make CC=clang CLANG_TRIPLE=aarch64-linux-gnu- CROSS_COMPILE=aarch64-linux-gnu- -j$(nproc) Image.gz dtbs

Output cần có:
- arch/arm64/boot/Image.gz
- arch/arm64/boot/dts/qcom/*.dtb (tìm file có tên picasso hoặc lito)

## 7. OFFSETS + CMDLINE CHUẨN CHO PICASSO (ANDROID 11 HEADER V2)
Đây là phần quan trọng nhất để không bootloop:

BOARD_KERNEL_BASE := 0x00000000
BOARD_KERNEL_PAGESIZE := 4096
BOARD_BOOTIMG_HEADER_VERSION := 2
BOARD_KERNEL_SEPARATED_DTBO := true
BOARD_INCLUDE_DTB_IN_BOOTIMG := true
BOARD_KERNEL_OFFSET := 0x00008000
BOARD_RAMDISK_OFFSET := 0x01000000
BOARD_TAGS_OFFSET := 0x00000100
BOARD_DTB_OFFSET := 0x01f00000
BOARD_KERNEL_IMAGE_NAME := Image.gz

CMDLINE chuẩn (đã thêm permissive cho Halium):
console=ttyMSM0,115200n8 earlycon=msm_geni_serial,0x4a90000 androidboot.hardware=qcom androidboot.console=ttyMSM0 androidboot.memcg=1 lpm_levels.sleep_disabled=1 video=vfb:640x400,bpp=32,memsize=3072000 msm_rtb.filter=0x237 service_locator.enable=1 swiotlb=1 androidboot.usbcontroller=a600000.dwc3 loop.max_part=7 androidboot.usbconfigfs=true androidboot.selinux=permissive

## 8. BUILD HALIUM-BOOT.IMG
Clone halium-boot:
git clone https://github.com/Halium/halium-boot -b halium-11.0 --depth 1
cd halium-boot
./build.sh (để tạo initramfs.cpio.gz)

Tìm DTB:
DTB=$(find ../kernel/arch/arm64/boot/dts/qcom -name "*picasso*.dtb" | head -n1)
Fallback nếu không có: tìm lito*.dtb

Tìm RAMDISK:
RAMDISK=$(find . -name "*.cpio.gz" | head -n1)

Pack boot.img bằng mkbootimg với offsets chuẩn ở mục 7:
mkbootimg --kernel Image.gz --ramdisk initramfs.cpio.gz --dtb picasso.dtb --base 0x00000000 --pagesize 4096 --kernel_offset 0x00008000 --ramdisk_offset 0x01000000 --tags_offset 0x00000100 --dtb_offset 0x01f00000 --header_version 2 --cmdline "<cmdline ở trên>" -o halium-boot-picasso.img

Hoặc dùng tool halium-boot:
./halium-boot/halium-boot --kernel Image.gz --dtb $DTB --ramdisk $RAMDISK -o halium-boot-picasso.img
Nhưng phải đảm bảo tool này đã được patch để dùng header v2 và offsets chuẩn.

## 9. CÁCH BUILD TRÊN GITHUB ACTIONS (KHÔNG CẦN MÁY LINUX)
Tạo repo mới, tạo file .github/workflows/build.yml với nội dung workflow v2.1 đã fix offsets (đính kèm file github_workflow_picasso_v2.yml).

Steps trong workflow:
- Install deps: bc bison build-essential flex libssl-dev libelf-dev clang lld llvm aarch64-linux-gnu-gcc
- Clone kernel PeterCxy lineage-18.1
- Tự dò defconfig
- Patch config cho Halium
- Build Image.gz + dtbs bằng clang
- Clone halium-boot halium-11.0, build ramdisk
- Pack halium-boot-picasso.img với offsets chuẩn
- Upload artifact halium-boot-picasso.img

Chạy workflow -> tải artifact.

## 10. FLASH DROIDIAN
Yêu cầu: Đã về MIUI V12.5.7.0.RGICNXM Android 11, đã có OrangeFox Recovery for picasso (bản mới nhất hỗ trợ Android 11 dynamic partition).

Các bước trong fastboot:
fastboot flash boot halium-boot-picasso.img
fastboot reboot recovery

Trong OrangeFox Recovery:
- Wipe -> Format data (nếu từ Android 16 xuống)
- Install zip: droidian-rootfs-api28gsi_arm64_*.zip (tải từ droidian.org - bản mới nhất)
- Install zip: droidian-devtools_arm64_*.zip
- Install zip: adaptation-monet.zip hoặc adaptation-lito.zip (nếu có, nếu không Droidian vẫn boot nhưng thiếu firmware)

Reboot -> Đợi 2-3 phút logo Droidian -> vào Phosh.
User: droidian / Pass: 1234

## 11. TROUBLESHOOTING
- Màn đen sau flash halium-boot: DTB sai. Giải pháp: Extract dtb từ boot.img stock V12.5.7.0.RGICNXM bằng Android boot image editor, pack lại với Image.gz mới.
- Bootloop logo Mi: Sai offsets hoặc header version. Kiểm tra lại phải là header v2, pagesize 4096, base 0x00000000.
- Không có sóng / wifi: Flash lại vendor zip V12.5.7.0 hoặc flash fw_picasso_miui_PICASSO_V12.5.7.0.RGICNXM_02c694af6e_11.0.zip trong fastbootd.
- Telnet debug: Nếu boot fail, Halium initramfs sẽ tạo RNDIS gadget 192.168.2.15, có thể telnet vào để xem log dmesg.
- Mất vân tay sau downgrade: Do persist. Restore persist backup.

## 12. TỶ LỆ THÀNH CÔNG ƯỚC TÍNH
- Build kernel thành công: 90%
- Pack halium-boot đúng chuẩn: 95%
- Boot lên Phosh (có màn hình): 65-80% (tùy DTB)
- Full chức năng (wifi, modem data): 50-60% lần đầu, lên 80% sau khi flash vendor và adaptation.

## 13. FILE ĐÍNH KÈM CẦN GỬI CHO AI KHÁC
- README_picasso_halium.md: Hướng dẫn build chi tiết
- build_halium_picasso.sh: Script build local
- github_workflow_picasso_v2.yml: Workflow GitHub Actions đã fix offsets + cmdline chuẩn

Yêu cầu AI khác: Kiểm tra lại defconfig tồn tại, kiểm tra offsets, build và đưa ra file halium-boot-picasso.img cuối cùng.
