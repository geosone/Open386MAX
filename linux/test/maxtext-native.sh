#!/bin/bash
# Copyright (C) 2026 Open386MAX contributors. SPDX-License-Identifier: GPL-3.0-only
# Native GD5446 80x60, public API, rollback, fonts and UMB loading.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
BIN=$ROOT/build/bin
TBIN=$ROOT/build/TESTS/MAXTEXT/bin
for dos in "${@:-msdos622}"; do
    for load in low high bootfont; do
        opts=''
        [ "$load" != bootfont ] || opts=' /MODE=80x60 /FONT=UNSCII'
        if [ "$load" = low ]; then
            cfg="DEVICE=C:\MAXTEXT.SYS$opts"
        elif [ "$dos" = edrdos ]; then
            cfg="DEVICE=C:\MAX\386MAX.SYS|DEVICE=C:\MAX\386LOAD.SYS PROG=C:\MAXTEXT.SYS$opts"
        else
            cfg="DEVICE=C:\MAX\386MAX.SYS|DOS=HIGH,UMB|DEVICEHIGH=C:\MAXTEXT.SYS$opts"
        fi
        fontcheck='REM ROM font'
        bootcheck='REM Runtime mode selection'
        if [ "$load" = bootfont ]; then
            fontcheck='C:\MTFTEST >> C:\MT.TXT'
            bootcheck='C:\MTUITEST 60 >> C:\MT.TXT|C:\MTFTEST >> C:\MT.TXT'
        fi
        out=$ROOT/build/test-maxtext-native-$dos-$load
        VGA=cirrus ACCEL=${ACCEL:--accel tcg} TESTDIR="$out" KEEP=1 \
        XFILES="$BIN/MAXTEXT.SYS $BIN/MAXTEXT.COM $TBIN/MTTEST.COM $TBIN/MTUITEST.EXE $TBIN/MTEXAPI.EXE $TBIN/MTFTEST.COM" \
        CONFIG="$cfg|FILES=40" \
        AUTO="@ECHO OFF|C:\MAXTEXT /STATUS > C:\MT.TXT|$bootcheck|C:\MTTEST >> C:\MT.TXT|C:\MAXTEXT /LIST >> C:\MT.TXT|C:\MTEXAPI 60 >> C:\MT.TXT|C:\MTUITEST 60 >> C:\MT.TXT|$fontcheck|C:\MAXTEXT /MODE:80x43 >> C:\MT.TXT|C:\MTUITEST 43 >> C:\MT.TXT|C:\MAXTEXT /MODE:80x50 >> C:\MT.TXT|C:\MTUITEST 50 >> C:\MT.TXT|C:\MAXTEXT /RESTORE >> C:\MT.TXT|C:\MTUITEST 25 >> C:\MT.TXT|TYPE C:\MT.TXT|ECHO MAXTEXT-NATIVE-END" \
        STEPS='wait:MAXTEXT-NATIVE-END:60 text:end' \
        bash "$ROOT/linux/test/dosboot.sh" "$dos" > "$ROOT/build/maxtext-native-$dos-$load.log" 2>&1
        mcopy -o -i "$out/test.img@@32256" ::/MT.TXT "$out/MT.TXT"
        python3 - "$out/MT.TXT" "$load" <<'PY'
from pathlib import Path
import re, sys
s = Path(sys.argv[1]).read_text(encoding='cp437')
for expected in ['MTTEST PASS', 'MTEXAPI PASS', '80x60', 'backend flags: 5']:
    assert expected in s, s
for rows in (60, 43, 50, 25):
    assert 'MTUITEST PASS: 80x'+str(rows) in s, s
assert 'FAIL' not in s and 'failed' not in s, s
assert '132x' not in s, s
segment = int(re.search(r'segment \(decimal\): (\d+)', s)[1])
if sys.argv[2] == 'low':
    assert segment < 0xa000, s
else:
    assert 0xc000 <= segment < 0xf000, s
if sys.argv[2] == 'bootfont':
    assert s.count('MTFTEST PASS') == 2, s
PY
        echo "PASS: GD5446 native 80x60, PLL/full rollback, API, QUILIB, $dos $load"
    done
done
# PCI faults must not grant native capability, even on an actual Cirrus model.
for fault in N S R L D; do
    out=$ROOT/build/test-maxtext-native-pci-$fault
    VGA=cirrus ACCEL=${ACCEL:--accel tcg} TESTDIR="$out" KEEP=1 \
    XFILES="$BIN/MAXTEXT.SYS $BIN/MAXTEXT.COM $TBIN/MTPCIFIX.SYS $TBIN/MTUITEST.EXE" \
    CONFIG="DEVICE=C:\MTPCIFIX.SYS /$fault|DEVICE=C:\MAXTEXT.SYS|FILES=40" \
    AUTO='@ECHO OFF|C:\MAXTEXT /LIST > C:\MT.TXT|C:\MAXTEXT /MODE:80x60 >> C:\MT.TXT|IF ERRORLEVEL 2 ECHO REJECT-PASS >> C:\MT.TXT|C:\MTUITEST 25 >> C:\MT.TXT|TYPE C:\MT.TXT|ECHO MAXTEXT-NATIVE-END' \
    STEPS='wait:MAXTEXT-NATIVE-END:45 text:end' \
    bash "$ROOT/linux/test/dosboot.sh" msdos622 > "$ROOT/build/maxtext-native-pci-$fault.log" 2>&1
    mcopy -o -i "$out/test.img@@32256" ::/MT.TXT "$out/MT.TXT"
    rg -q 'REJECT-PASS' "$out/MT.TXT"
    rg -q 'MTUITEST PASS: 80x25' "$out/MT.TXT"
    ! rg -q '^80x60' "$out/MT.TXT"
    echo "PASS: PCI fault $fault grants no native mode"
done
