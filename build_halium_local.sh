#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# SCRIPT BUILD HALIUM-BOOT.IMG CHO REDMI K30 5G (PICASSO) - SM7250 LITO
# ==============================================================================

WORK_DIR="$(pwd)"
KERNEL_DIR="${WORK_DIR}/kernel"
OUTPUT_DIR="${WORK_DIR}/output"
OUT_DIR="${KERNEL_DIR}/out_halium"

KERNEL_REPO="https://github.com/LineageOS/android_kernel_xiaomi_sm7250"
KERNEL_BRANCH="lineage-18.1"
DEFCONFIG="vendor/picasso_user_defconfig"
FALLBACK_DEFCONFIG="vendor/lito-perf_defconfig"

# Boot Image Parameters (Header V2 - Picasso)
BASE="0x00000000"
PAGESIZE="4096"
HEADER_VERSION="2"
KERNEL_OFFSET="0x00008000"
RAMDISK_OFFSET="0x01000000"
TAGS_OFFSET="0x00000100"
DTB_OFFSET="0x01f00000"

CMDLINE="earlycon=msm_geni_serial,0x4a90000 androidboot.hardware=qcom androidboot.memcg=1 lpm_levels.sleep_disabled=1 msm_rtb.filter=0x237 service_locator.enable=1 swiotlb=2048 androidboot.usbcontroller=a600000.dwc3 loop.max_part=7 androidboot.usbconfigfs=true androidboot.selinux=permissive"

echo "=== KHỞI ĐỘNG TIẾN TRÌNH BUILD HALIUM-BOOT CHO PICASSO ==="
mkdir -p "${OUTPUT_DIR}"

# 0. Thiết lập Toolchain nếu có sẵn trong thư mục
if [ -d "${WORK_DIR}/toolchain/clang/bin" ]; then
    export PATH="${WORK_DIR}/toolchain/clang/bin:${PATH}"
    echo "[+] Đã kích hoạt toolchain tại ${WORK_DIR}/toolchain/clang/bin"
fi

# 1. Kiểm tra Dependencies
echo "[1/6] Kiểm tra các công cụ phụ thuộc..."
MISSING_PKGS=()
for tool in git make clang aarch64-linux-gnu-gcc bison flex bc mkbootimg; do
    if ! command -v "$tool" &> /dev/null; then
        MISSING_PKGS+=("$tool")
    fi
done

if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
    echo "[-] Cảnh báo: Thiếu các công cụ sau: ${MISSING_PKGS[*]}"
    echo "    Bạn có thể cài đặt bằng lệnh (Ubuntu/Debian):"
    echo "    sudo apt-get update && sudo apt-get install -y bc bison build-essential flex libssl-dev libelf-dev clang lld llvm gcc-aarch64-linux-gnu python3-pip"
    echo "    pip3 install mkbootimg"
    read -p "Bạn có muốn tiếp tục thử chạy không? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# 2. Clone Kernel Source (nếu chưa có)
echo "[2/6] Chuẩn bị mã nguồn Kernel..."
if [ ! -d "${KERNEL_DIR}" ]; then
    echo "[*] Đang clone kernel từ ${KERNEL_REPO} (branch ${KERNEL_BRANCH})..."
    git clone --depth=1 -b "${KERNEL_BRANCH}" "${KERNEL_REPO}" "${KERNEL_DIR}"
else
    echo "[+] Đã tìm thấy thư mục kernel tại ${KERNEL_DIR}."
fi

cd "${KERNEL_DIR}"

# 3. Cấu hình Defconfig
echo "[3/6] Thiết lập cấu hình defconfig..."
export ARCH=arm64
export SUBARCH=arm64

if [ -f "arch/arm64/configs/${DEFCONFIG}" ]; then
    echo "[+] Sử dụng defconfig: ${DEFCONFIG}"
    make O="${OUT_DIR}" ARCH=arm64 "${DEFCONFIG}"
elif [ -f "arch/arm64/configs/${FALLBACK_DEFCONFIG}" ]; then
    echo "[!] Không thấy ${DEFCONFIG}, dùng fallback: ${FALLBACK_DEFCONFIG}"
    make O="${OUT_DIR}" ARCH=arm64 "${FALLBACK_DEFCONFIG}"
else
    echo "[-] Lỗi: Không tìm thấy defconfig phù hợp!"
    exit 1
fi

# 4. Áp dụng các Patch Config cho Halium / Droidian / LXC
echo "[4/6] Áp dụng kernel config patches cho Halium & Droidian..."
SC="scripts/config"
CFG="${OUT_DIR}/.config"

# --- Android Binder & IPC (Kernel 4.19 dùng binder legacy devices, không dùng BINDERFS) ---
$SC --file "$CFG" --enable CONFIG_ANDROID
$SC --file "$CFG" --enable CONFIG_ANDROID_BINDER_IPC
$SC --file "$CFG" --set-str CONFIG_ANDROID_BINDER_DEVICES "binder,hwbinder,vndbinder"
$SC --file "$CFG" --enable CONFIG_ASHMEM

# --- Namespaces cho LXC Container ---
$SC --file "$CFG" --enable CONFIG_NAMESPACES
$SC --file "$CFG" --enable CONFIG_UTS_NS
$SC --file "$CFG" --enable CONFIG_IPC_NS
$SC --file "$CFG" --enable CONFIG_USER_NS
$SC --file "$CFG" --enable CONFIG_PID_NS
$SC --file "$CFG" --enable CONFIG_NET_NS

# --- Cgroups ---
$SC --file "$CFG" --enable CONFIG_CGROUPS
$SC --file "$CFG" --enable CONFIG_CPUSETS
$SC --file "$CFG" --enable CONFIG_CGROUP_DEVICE
$SC --file "$CFG" --enable CONFIG_CGROUP_FREEZER
$SC --file "$CFG" --enable CONFIG_BLK_CGROUP
$SC --file "$CFG" --enable CONFIG_CGROUP_PERF

# --- AppArmor & Security ---
$SC --file "$CFG" --enable CONFIG_SECURITY
$SC --file "$CFG" --enable CONFIG_SECURITY_APPARMOR
$SC --file "$CFG" --enable CONFIG_SECURITY_APPARMOR_HASH
$SC --file "$CFG" --enable CONFIG_DEFAULT_SECURITY_APPARMOR
$SC --file "$CFG" --set-str CONFIG_DEFAULT_SECURITY "apparmor"
$SC --file "$CFG" --set-val CONFIG_SECURITY_APPARMOR_BOOTPARAM_VALUE 1
$SC --file "$CFG" --set-val CONFIG_SECURITY_SELINUX_BOOTPARAM_VALUE 0
$SC --file "$CFG" --enable CONFIG_SECCOMP
$SC --file "$CFG" --enable CONFIG_SECURITYFS
$SC --file "$CFG" --enable CONFIG_SECURITY_NETWORK
$SC --file "$CFG" --enable CONFIG_SECURITY_PATH
$SC --file "$CFG" --enable CONFIG_AUDIT

# --- Virtual Terminal, SysV IPC & Devtmpfs ---
$SC --file "$CFG" --enable CONFIG_VT
$SC --file "$CFG" --enable CONFIG_VT_CONSOLE
$SC --file "$CFG" --enable CONFIG_SYSVIPC
$SC --file "$CFG" --enable CONFIG_DEVTMPFS
$SC --file "$CFG" --enable CONFIG_DEVTMPFS_MOUNT
$SC --file "$CFG" --enable CONFIG_DEVPTS_MULTIPLE_INSTANCES

# --- File systems ---
$SC --file "$CFG" --enable CONFIG_TMPFS_XATTR
$SC --file "$CFG" --enable CONFIG_TMPFS_POSIX_ACL
$SC --file "$CFG" --enable CONFIG_AUTOFS4_FS
$SC --file "$CFG" --enable CONFIG_EXT4_FS_POSIX_ACL
$SC --file "$CFG" --enable CONFIG_EXT4_FS_SECURITY
$SC --file "$CFG" --enable CONFIG_FHANDLE
$SC --file "$CFG" --enable CONFIG_IKCONFIG
$SC --file "$CFG" --enable CONFIG_IKCONFIG_PROC

# --- Network, Bridge & IPTables cho Container ---
$SC --file "$CFG" --enable CONFIG_BRIDGE
$SC --file "$CFG" --enable CONFIG_VETH
$SC --file "$CFG" --enable CONFIG_MACVLAN
$SC --file "$CFG" --enable CONFIG_NF_NAT
$SC --file "$CFG" --enable CONFIG_IP_NF_NAT
$SC --file "$CFG" --enable CONFIG_IP_NF_IPTABLES
$SC --file "$CFG" --enable CONFIG_NF_CONNTRACK
$SC --file "$CFG" --enable CONFIG_NETFILTER_XT_MATCH_ADDRTYPE
$SC --file "$CFG" --enable CONFIG_NETFILTER_XT_MATCH_CONNTRACK
$SC --file "$CFG" --enable CONFIG_NETFILTER_XT_MATCH_MULTIPORT
$SC --file "$CFG" --enable CONFIG_NETFILTER_XT_MATCH_STATE
$SC --file "$CFG" --enable CONFIG_NETFILTER_XT_MATCH_PHYSDEV
$SC --file "$CFG" --enable CONFIG_NETFILTER_XT_TARGET_MARK
$SC --file "$CFG" --enable CONFIG_NETFILTER_XT_TARGET_CONNMARK
$SC --file "$CFG" --enable CONFIG_NETFILTER_XT_TARGET_LOG
$SC --file "$CFG" --enable CONFIG_IP_ADVANCED_ROUTER
$SC --file "$CFG" --enable CONFIG_PSI
$SC --file "$CFG" --disable CONFIG_COMPAT_VDSO
$SC --file "$CFG" --enable CONFIG_USB_CONFIGFS_RNDIS  # halium telnet rescue
$SC --file "$CFG" --enable CONFIG_USB_CONFIGFS_ECM
sed -i "s/# CONFIG_TOUCHSCREEN_NT36xxx_HOSTDL_SPI is not set/CONFIG_TOUCHSCREEN_NT36xxx_HOSTDL_SPI=y/" "$CFG"  # picasso novatek touch (scripts/config mishandles it)
sed -i "s/# CONFIG_ION_SYSTEM_HEAP is not set/CONFIG_ION_SYSTEM_HEAP=y/" "$CFG"  # gralloc needs ION system heap on 4.19

# --- Vô hiệu hóa các tính năng cản trở Linux userspace ---
$SC --file "$CFG" --disable CONFIG_ANDROID_LOW_MEMORY_KILLER
$SC --file "$CFG" --disable CONFIG_ANDROID_PARANOID_NETWORK
$SC --file "$CFG" --disable CONFIG_DEFAULT_SECURITY_SELINUX

# 5. Build Kernel Image & DTBs
echo "[*] olddefconfig tu dong..."
make O="${OUT_DIR}" ARCH=arm64 olddefconfig
echo "[5/6] Bắt đầu biên dịch Kernel (Image.gz & dtbs)..."
make O="${OUT_DIR}" ARCH=arm64 \
     CC=clang \
     CLANG_TRIPLE=aarch64-linux-gnu- \
     CROSS_COMPILE=aarch64-linux-gnu- \
     CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
     PYTHON=python2 \
     -j"$(nproc)" \
     Image.gz dtbs

KERNEL_IMAGE="${OUT_DIR}/arch/arm64/boot/Image.gz"
if [ ! -f "${KERNEL_IMAGE}" ]; then
    echo "[-] Lỗi: Không tạo được file Image.gz tại ${KERNEL_IMAGE}"
    exit 1
fi
echo "[+] Build Kernel thành công: ${KERNEL_IMAGE}"

# Tìm DTB
echo "[*] Đang chuẩn bị Device Tree Blob (DTB)..."
DTB_DIR="${OUT_DIR}/arch/arm64/boot/dts"
DTB_FILE="${OUTPUT_DIR}/picasso-lito-combined.dtb"

LITO_DTB1=$(find "${DTB_DIR}" -name "lito.dtb" 2>/dev/null | head -n1 || true)
LITO_DTB2=$(find "${DTB_DIR}" -name "lito-v2.dtb" 2>/dev/null | head -n1 || true)

if [ -n "${LITO_DTB1}" ] && [ -n "${LITO_DTB2}" ]; then
    cat "${LITO_DTB1}" "${LITO_DTB2}" > "${DTB_FILE}"
elif [ -n "${LITO_DTB1}" ]; then
    cp "${LITO_DTB1}" "${DTB_FILE}"
else
    echo "[-] Lỗi: Không tìm thấy file DTB cho lito!"
    exit 1
fi
echo "[+] Đã tạo file DTB gộp: ${DTB_FILE}"

# 6. Chuẩn bị Ramdisk & Pack Boot Image
echo "[6/6] Chuẩn bị Ramdisk và đóng gói halium-boot.img..."
cd "${WORK_DIR}"

RAMDISK_FILE="${WORK_DIR}/ramdisk.cpio.gz"
if [ ! -f "${RAMDISK_FILE}" ]; then
    # Lấy Halium Generic Ramdisk
    if [ ! -d "${WORK_DIR}/hgabt" ]; then
        echo "[*] Đang tải halium-generic-adaptation-build-tools..."
        git clone --depth=1 -b halium-11 https://gitlab.com/ubports/porting/community-ports/halium-generic-adaptation-build-tools.git "${WORK_DIR}/hgabt" || true
    fi

    # Thử tìm ramdisk có sẵn hoặc fallback halium-boot
    FOUND_RD=$(find "${WORK_DIR}" -name "initrd.img" -o -name "*initramfs*.cpio.gz" 2>/dev/null | head -n1 || true)
    if [ -n "${FOUND_RD}" ]; then
        RAMDISK_FILE="${FOUND_RD}"
    else
        echo "[*] Đang build ramdisk qua halium-boot..."
        if [ ! -d "${WORK_DIR}/halium-boot" ]; then
            git clone --depth=1 https://github.com/Halium/halium-boot.git "${WORK_DIR}/halium-boot"
        fi
        cd "${WORK_DIR}/halium-boot"
        if [ -f "./build.sh" ]; then
            ./build.sh || true
        fi
        RAMDISK_FILE=$(find . -name "*.cpio.gz" | head -n1 || true)
        cd "${WORK_DIR}"
    fi
fi

if [ -z "${RAMDISK_FILE}" ] || [ ! -f "${RAMDISK_FILE}" ]; then
    echo "[-] Cảnh báo: Chưa tìm thấy ramdisk.cpio.gz tự động."
    echo "    Vui lòng đặt file ramdisk Halium 11 (initrd.img hoặc ramdisk.cpio.gz) vào thư mục gốc rồi chạy lại phần pack."
    echo "    Lệnh đóng gói mẫu:"
    echo "    mkbootimg --kernel ${KERNEL_IMAGE} --ramdisk <ramdisk_file> --dtb ${DTB_FILE} \\"
    echo "              --base ${BASE} --pagesize ${PAGESIZE} --kernel_offset ${KERNEL_OFFSET} \\"
    echo "              --ramdisk_offset ${RAMDISK_OFFSET} --tags_offset ${TAGS_OFFSET} --dtb_offset ${DTB_OFFSET} \\"
    echo "              --header_version ${HEADER_VERSION} --cmdline \"${CMDLINE}\" \\"
    echo "              -o ${OUTPUT_DIR}/halium-boot-picasso.img"
    exit 0
fi

echo "[+] Sử dụng Ramdisk: ${RAMDISK_FILE}"

FINAL_BOOT_IMG="${OUTPUT_DIR}/halium-boot-picasso.img"
echo "[*] Đang đóng gói boot.img (Header V2)..."

mkbootimg \
    --kernel "${KERNEL_IMAGE}" \
    --ramdisk "${RAMDISK_FILE}" \
    --dtb "${DTB_FILE}" \
    --base "${BASE}" \
    --pagesize "${PAGESIZE}" \
    --kernel_offset "${KERNEL_OFFSET}" \
    --ramdisk_offset "${RAMDISK_OFFSET}" \
    --tags_offset "${TAGS_OFFSET}" \
    --dtb_offset "${DTB_OFFSET}" \
    --header_version "${HEADER_VERSION}" \
    --cmdline "${CMDLINE}" \
    -o "${FINAL_BOOT_IMG}"

echo
echo "=========================================================="
echo "  HOÀN THÀNH THÀNH CÔNG!"
echo "  File boot image đầu ra: ${FINAL_BOOT_IMG}"
echo "=========================================================="
