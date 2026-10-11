#!/usr/bin/env bash
set -euo pipefail

echo "=========================================================="
echo "  TOOL KIỂM TRA ANTI-ROLLBACK (ARB) - REDMI K30 5G (PICASSO)"
echo "=========================================================="
echo

# 1. Kiểm tra fastboot binary
if ! command -v fastboot &> /dev/null; then
    echo "[-] Lỗi: Không tìm thấy lệnh 'fastboot'. Vui lòng cài đặt android-tools hoặc platform-tools."
    exit 1
fi

echo "[*] Đang kiểm tra thiết bị ở Fastboot mode..."
FASTBOOT_DEVICES=$(fastboot devices)
if [ -z "$FASTBOOT_DEVICES" ]; then
    echo "[-] Không tìm thấy thiết bị fastboot nào được kết nối!"
    echo "    Vui lòng đưa máy về Fastboot (Nhấn giữ Volume Down + Nguồn) và cắm cáp USB."
    exit 1
fi

echo "[+] Đã phát hiện thiết bị:"
echo "$FASTBOOT_DEVICES"
echo

# 2. Kiểm tra Codename thiết bị
DEVICE_PRODUCT=$(fastboot getvar product 2>&1 | grep "product:" | awk '{print $2}' || true)
echo "[*] Mã thiết bị (product): ${DEVICE_PRODUCT:-Không rõ}"
if [[ "$DEVICE_PRODUCT" != *"picasso"* ]]; then
    echo "[!] CẢNH BÁO: Thiết bị hiện tại không có mã 'picasso' (${DEVICE_PRODUCT}). Cẩn thận khi tiếp tục!"
fi

# 3. Lấy chỉ số ARB trên máy
echo "[*] Đang đọc Anti-Rollback index trên chip..."
ANTI_OUTPUT=$(fastboot getvar anti 2>&1 || true)
DEVICE_ANTI=$(echo "$ANTI_OUTPUT" | grep "anti:" | awk '{print $2}' || true)

if [ -z "$DEVICE_ANTI" ]; then
    echo "[!] Kết quả 'fastboot getvar anti': Không có giá trị cụ thể (hoặc báo lỗi/trống)."
    echo "    Điều này thường có nghĩa là ARB chưa bị kích hoạt nghiêm ngặt trên firmware hiện tại."
    DEVICE_ANTI_NUM=0
else
    echo "[+] Chỉ số ARB hiện tại của máy (Device ARB): ${DEVICE_ANTI}"
    DEVICE_ANTI_NUM="$DEVICE_ANTI"
fi
echo

# 4. Kiểm tra file ROM nếu người dùng cung cấp đường dẫn
if [ $# -ge 1 ]; then
    ROM_PATH="$1"
    echo "[*] Đang kiểm tra thư mục ROM giải nén tại: $ROM_PATH"
    if [ -f "$ROM_PATH/flash_all.sh" ] || [ -f "$ROM_PATH/flash_all.bat" ]; then
        ROM_ANTI=""
        if [ -f "$ROM_PATH/flash_all.sh" ]; then
            ROM_ANTI=$(grep -i "CURRENT_ANTI_VER" "$ROM_PATH/flash_all.sh" | grep -o "[0-9]\+" | head -n1 || true)
        fi
        if [ -z "$ROM_ANTI" ] && [ -f "$ROM_PATH/flash_all.bat" ]; then
            ROM_ANTI=$(grep -i "CURRENT_ANTI_VER" "$ROM_PATH/flash_all.bat" | grep -o "[0-9]\+" | head -n1 || true)
        fi

        if [ -n "$ROM_ANTI" ]; then
            echo "[+] Chỉ số ARB của ROM mục tiêu (ROM ARB): $ROM_ANTI"
            echo "----------------------------------------------------------"
            if [ "$DEVICE_ANTI_NUM" -gt "$ROM_ANTI" ]; then
                echo "[X] NGUY HIỂM: Device ARB ($DEVICE_ANTI_NUM) > ROM ARB ($ROM_ANTI)"
                echo "    --> FLASH BẢN ROM NÀY SẼ DẪN ĐẾN HARD BRICK (MẤT BOOTLOADER)!"
                echo "    --> TUYỆT ĐỐI KHÔNG FLASH!"
                exit 2
            else
                echo "[✓] AN TOÀN: Device ARB ($DEVICE_ANTI_NUM) <= ROM ARB ($ROM_ANTI)"
                echo "    --> Có thể flash bản ROM này mà không bị brick do ARB."
            fi
        else
            echo "[?] Không tìm thấy biến 'CURRENT_ANTI_VER' trong flash_all.sh / flash_all.bat."
            echo "    Bản ROM này có thể không ràng buộc chỉ số ARB cố định."
        fi
    else
        echo "[!] Không tìm thấy flash_all.sh hoặc flash_all.bat trong đường dẫn chỉ định."
    fi
else
    echo "[i] Hướng dẫn: Bạn có thể chạy:"
    echo "    $0 /duong/dan/thu_muc_rom_da_giai_nen"
    echo "    để script tự động so sánh Device ARB với ROM ARB."
fi

echo
echo "=========================================================="
