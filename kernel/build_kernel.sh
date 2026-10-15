#!/bin/bash
# Build picasso kernel (lineage-18.1 + Droidian/DS patches).
# Two modes:
#  1. CI/fresh: repo root has kernel/{picasso_defconfig,patches/} only;
#     source is cloned to kernel-src/.
#  2. Build machine: kernel source already at $ROOT/kernel (in place);
#     repo files live inside it (force-added to git).
# Tested on Ubuntu 22.04, 6+ cores, ~10GB free.
set -e
ROOT="${1:-$HOME/droidian}"
UPSTREAM="https://github.com/LineageOS/android_kernel_xiaomi_sm7250.git"
BRANCH="lineage-18.1"

if [ -d "$ROOT/kernel/arch" ] && [ -d "$ROOT/kernel/drivers" ]; then
  K="$ROOT/kernel"          # in-place source tree (build machine)
else
  K="$ROOT/kernel-src"      # fresh clone (CI)
  [ -d "$K" ] || git clone --depth 1 -b "$BRANCH" "$UPSTREAM" "$K"
fi
PATCHDIR="$ROOT/kernel/patches"
cd "$K"

for p in "$PATCHDIR"/0000-*.patch "$PATCHDIR"/0001-*.patch "$PATCHDIR"/01.*.patch "$PATCHDIR"/02.*.patch; do
  [ -f "$p" ] || continue
  if patch -p1 --dry-run < "$p" >/dev/null 2>&1; then
    echo "applying $(basename $p)"
    patch -p1 < "$p"
  else
    echo "skip (already applied?): $(basename $p)"
  fi
done

mkdir -p out_halium
cp "$ROOT/kernel/picasso_defconfig" out_halium/.config

# Proton clang 13 preferred (tested); fall back to system cross-gcc (CI).
if [ -x "$ROOT/toolchain/clang/bin/clang" ]; then
  export PATH="$ROOT/toolchain/clang/bin:$PATH"
  CC=clang
else
  echo "no Proton clang, using system gcc"
  CC=gcc
fi
if [ "$CC" = clang ]; then
  CCENV="CC=clang CLANG_TRIPLE=aarch64-linux-gnu-"
else
  CCENV="CC=gcc"
fi

make O=out_halium ARCH=arm64 $CCENV \
  CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
  PYTHON=python2 olddefconfig
make O=out_halium ARCH=arm64 $CCENV \
  CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
  PYTHON=python2 -j"$(nproc)" Image.gz dtbs
ls -la out_halium/arch/arm64/boot/Image.gz

# Modules: required on the device rootfs (Wi-Fi etc.). Stripped AND signed
# with the kernel's certs/signing_key.pem (kernel enforces MODULE_SIG_FORCE).
make O=out_halium ARCH=arm64 $CCENV \
  CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
  PYTHON=python2 -j"$(nproc)" modules
rm -rf out_modules
make O=out_halium ARCH=arm64 $CCENV \
  CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
  PYTHON=python2 INSTALL_MOD_PATH="$K/out_modules" INSTALL_MOD_STRIP=1 modules_install
REL="$(cat out_halium/include/config/kernel.release)"
mkdir -p "$ROOT/output"
tar czf "$ROOT/output/kernel-modules-$REL.tar.gz" -C "$K/out_modules" lib
echo "modules tarball: $ROOT/output/kernel-modules-$REL.tar.gz"
echo "device: tar xzf kernel-modules-$REL.tar.gz -C / && depmod -a $REL"
cat out_halium/include/config/kernel.release
