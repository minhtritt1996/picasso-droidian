#!/bin/bash
# Patch vendor .ko vermagic to the RUNNING kernel (same length required).
# TESTED: vendor 4.19.113-perf-* -> 4.19.113-lineage-picasso+ (70 -> 56+NUL pad).
# Usage on phone: ./patch-modules.sh /android/vendor/lib/modules /root/vmods
set -e
SRC="${1:-/android/vendor/lib/modules}"
DST="${2:-/root/vmods}"
REL="$(uname -r)"
OLD='4.19.113-perf-g481f117a1553 SMP preempt mod_unload modversions aarch64'
NEW="$REL SMP preempt mod_unload aarch64"
[ ${#NEW} -le ${#OLD} ] || { echo "new vermagic longer, abort"; exit 1; }
mkdir -p "$DST"
python3 - "$SRC" "$DST" "$OLD" "$NEW" <<'EOF'
import glob, os, sys
src, dst, old, new = sys.argv[1], sys.argv[2], sys.argv[3].encode(), sys.argv[4].encode()
pad = new + b'\x00' * (len(old) - len(new))
n = 0
for f in sorted(glob.glob(src + '/*.ko')):
    d = open(f, 'rb').read()
    if old in d:
        d2 = d.replace(old, pad)
        assert len(d2) == len(d)
        d = d2; n += 1
    open(dst + '/' + os.path.basename(f), 'wb').write(d)
print('patched', n)
EOF
