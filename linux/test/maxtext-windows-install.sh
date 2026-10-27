#!/bin/bash
# Open 386MAX
# Copyright: Open 386MAX contributors 2026.
# GNU General Public License version 3; see LICENSE.
# SPDX-License-Identifier: GPL-3.0-only
#
# Windows 3.11 setup: default-on MAXTEXT and Configure-page opt-out.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
pkg=${PKG:-$ROOT/build/package}
OUT=$ROOT/build/test-maxtext-windows-install
mkdir -p "$OUT"
cp "$pkg/SETUP.INF" "$OUT/SETUP.DEFAULT.INF"
trap 'cp "$OUT/SETUP.DEFAULT.INF" "$pkg/SETUP.INF"' EXIT
if [ "${PRESERVE_OPTIONS:-0}" = 1 ]; then
    export EXTRA_CONFIG='DEVICE=C:\MAX\MAXTEXT.SYS /MODE=80x50 /FONT=ROM'
fi
for enabled in ${ENABLED_VALUES:-1 0}; do
    cat > "$pkg/SETUP.INF" <<INI
[Setup]
Unattended=1
Directory=C:\QMAX
ConfigChanges=Apply
RunMaximize=0
[386MAX]
MaxText=$enabled
EMS=0
MDA=0
MemoryTester=0
[Windows]
GoAhead=0
MAXmeter=0
INI
    ACCEL=${ACCEL:--accel tcg} MM=himem SETUPPKG=1 SETUPDIR="$pkg" \
        TIMEOUT=${BOOT_WAIT:-65} SHOTS='25 45' \
        bash "$ROOT/linux/test/win311.sh" SETUP > "$OUT/setup-$enabled.log" 2>&1
    mkdir -p "$OUT/$enabled"
    P=$ROOT/build/win311test/test.img@@32256
    mcopy -o -i "$P" ::/CONFIG.SYS "$OUT/$enabled/CONFIG.SYS"
    mcopy -o -i "$P" ::/QMAX/MAXTEXT.SYS "$OUT/$enabled/MAXTEXT.SYS"
    cp "$ROOT/build/win311test/screen.png" "$OUT/$enabled/final.png"
    python3 - "$OUT/$enabled" "$enabled" "$ROOT" <<'PY'
from pathlib import Path
import os,sys
out,root=Path(sys.argv[1]),Path(sys.argv[3])
assert (out/'MAXTEXT.SYS').read_bytes()==(root/'build/bin/MAXTEXT.SYS').read_bytes()
s=(out/'CONFIG.SYS').read_text()
active=[l for l in s.splitlines() if l.strip().lower().startswith('device') and 'maxtext.sys' in l.lower()]
if sys.argv[2]=='1':
    assert len(active)==1 and '386load.sys' in active[0].lower(),s
    if os.getenv('PRESERVE_OPTIONS')=='1':
        assert '/MODE=80x50' in active[0] and '/FONT=ROM' in active[0],s
    assert s.lower().index('386max.sys') < s.lower().index('maxtext.sys'),s
else: assert not active,s
print('PASS: Windows setup MAXTEXT '+('default enabled' if sys.argv[2]=='1' else 'opt-out'))
PY
done
