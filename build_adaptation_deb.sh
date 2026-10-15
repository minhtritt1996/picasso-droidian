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

chmod 755 "$PKG_DIR/DEBIAN/postinst" 2>/dev/null || true
chmod +x "$PKG_DIR/usr/local/bin/"* 2>/dev/null || true

VERSION=$(grep '^Version:' "$PKG_DIR/DEBIAN/control" | awk '{print $2}')
[ -n "$VERSION" ] || VERSION="1.1.0"

echo "=== Building adaptation-xiaomi-picasso_${VERSION}_arm64.deb ==="
dpkg-deb --build --root-owner-group "$PKG_DIR" "$OUT_DIR/adaptation-xiaomi-picasso_${VERSION}_arm64.deb"
echo "Package built at: $OUT_DIR/adaptation-xiaomi-picasso_${VERSION}_arm64.deb"
md5sum "$OUT_DIR/adaptation-xiaomi-picasso_${VERSION}_arm64.deb"

