#!/bin/bash
# Script to build adaptation-xiaomi-picasso.deb
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_DIR="$DIR/packages/adaptation-xiaomi-picasso"
OUT_DIR="$DIR/output"

mkdir -p "$OUT_DIR"

if [ ! -d "$PKG_DIR/DEBIAN" ]; then
    echo "Error: $PKG_DIR/DEBIAN does not exist."
    exit 1
fi

# Normalize permissions before packaging: dpkg preserves archive modes, and
# Android init skips group/other-writable vendor rc files as insecure.
find "$PKG_DIR" -type d -exec chmod 755 {} +
find "$PKG_DIR" -type f -exec chmod 644 {} +
chmod 755 "$PKG_DIR/DEBIAN/postinst"
find "$PKG_DIR/usr/local/bin" "$PKG_DIR/usr/bin" -type f -exec chmod 755 {} + 2>/dev/null || true

VERSION=$(grep '^Version:' "$PKG_DIR/DEBIAN/control" | awk '{print $2}')
[ -n "$VERSION" ] || VERSION="1.1.0"

echo "=== Building adaptation-xiaomi-picasso_${VERSION}_arm64.deb ==="
dpkg-deb --build --root-owner-group "$PKG_DIR" "$OUT_DIR/adaptation-xiaomi-picasso_${VERSION}_arm64.deb"
echo "Package built at: $OUT_DIR/adaptation-xiaomi-picasso_${VERSION}_arm64.deb"
md5sum "$OUT_DIR/adaptation-xiaomi-picasso_${VERSION}_arm64.deb"

