#!/bin/bash
# Copyright (C) 2026 Open386MAX contributors. SPDX-License-Identifier: GPL-3.0-only
# Test-only BIOS fixture on QEMU standard VGA. Does not establish card support.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
OUT=$ROOT/build/test-maxtext-vbe
BIN=$ROOT/build/bin
TBIN=$ROOT/build/TESTS/MAXTEXT/bin
ACCEL=${ACCEL:--accel tcg} TESTDIR="$OUT" KEEP=1 \
XFILES="$BIN/MAXTEXT.SYS $BIN/MAXTEXT.COM $TBIN/MTVBEFIX.SYS $TBIN/MTUITEST.EXE $TBIN/MTTEST.COM" \
CONFIG='DEVICE=C:\MTVBEFIX.SYS|DEVICE=C:\MAXTEXT.SYS|FILES=40' \
AUTO='@ECHO OFF|C:\MAXTEXT /LIST > C:\MT.TXT|C:\MAXTEXT /SELECT|C:\MTUITEST 60 >> C:\MT.TXT|C:\MAXTEXT /STATUS >> C:\MT.TXT|C:\MTTEST >> C:\MT.TXT|C:\MAXTEXT /MODE:80x60 >> C:\MT.TXT|C:\MTUITEST 60 >> C:\MT.TXT|C:\MAXTEXT /MODE:80x50 >> C:\MT.TXT|C:\MTUITEST 50 >> C:\MT.TXT|TYPE C:\MT.TXT|ECHO MAXTEXT-VBE-END' \
STEPS='wait:Choose:45 text:menu key:4 wait:MAXTEXT-VBE-END:60 text:end' \
bash "$ROOT/linux/test/dosboot.sh" msdos622 > "$ROOT/build/maxtext-vbe-boot.log" 2>&1
mcopy -o -i "$OUT/test.img@@32256" ::/MT.TXT "$OUT/MT.TXT"
python3 - "$OUT" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]);s=(p/'MT.TXT').read_text()
assert '80x60' in s and '132x' not in s,s
assert 'MTTEST PASS' in s,s
assert s.count('MTUITEST PASS: 80x60')==2,s
assert 'MTUITEST PASS: 80x50' in s,s
assert 'FAIL' not in s and 'failed' not in s,s
assert '4: 80x60' in (p/'menu.txt').read_text(),(p/'menu.txt').read_text()
print('PASS: VBE metadata filtering, SELECT, hardware 80x60, VBE state rollback and return to VGA')
PY
# Bad/unterminated pointers and missing SVGA state must grant no VBE modes.
for case in B W S F V A; do
    out=$ROOT/build/test-maxtext-vbe-$case
    ACCEL=${ACCEL:--accel tcg} TESTDIR="$out" KEEP=1 \
    XFILES="$BIN/MAXTEXT.SYS $BIN/MAXTEXT.COM $TBIN/MTVBEFIX.SYS $TBIN/MTUITEST.EXE" \
    CONFIG="DEVICE=C:\MTVBEFIX.SYS /$case|DEVICE=C:\MAXTEXT.SYS|FILES=40" \
    AUTO='@ECHO OFF|C:\MAXTEXT /LIST > C:\MT.TXT|C:\MAXTEXT /MODE:80x60 >> C:\MT.TXT|IF ERRORLEVEL 2 ECHO REJECT-PASS >> C:\MT.TXT|C:\MTUITEST 25 >> C:\MT.TXT|TYPE C:\MT.TXT|ECHO MAXTEXT-VBE-END' \
    STEPS='wait:MAXTEXT-VBE-END:45 text:end' \
    bash "$ROOT/linux/test/dosboot.sh" msdos622 > "$ROOT/build/maxtext-vbe-$case.log" 2>&1
    mcopy -o -i "$out/test.img@@32256" ::/MT.TXT "$out/MT.TXT"
    rg -q 'REJECT-PASS' "$out/MT.TXT"
    rg -q 'MTUITEST PASS: 80x25' "$out/MT.TXT"
    if [ "$case" = F ] || [ "$case" = A ]; then
        rg -q 'API result: 4' "$out/MT.TXT"
    else
        ! rg -q '^80x60' "$out/MT.TXT"
    fi
    echo "PASS: VBE negative fixture $case"
done
