#!/bin/bash
# Copyright (C) 2026 Open386MAX contributors. SPDX-License-Identifier: GPL-3.0-only
# PCI inventory and unchanged QUILIB text geometry on real QEMU adapters.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
TBIN=$ROOT/build/TESTS/MAXTEXT/bin
BIN=$ROOT/build/bin
for adapter in std cirrus; do
    for driver in absent loaded; do
        out=$ROOT/build/test-maxtext-svga-$adapter-$driver
        config='FILES=40'
        files="$TBIN/MTSVGA.COM $TBIN/MTUITEST.EXE"
        setup='C:\MTUITEST 50 80 BIOS > C:\MT.TXT'
        if [ "$driver" = loaded ]; then
            config='DEVICE=C:\MAX\386MAX.SYS|DOS=HIGH,UMB|DEVICEHIGH=C:\MAXTEXT.SYS|FILES=40'
            files="$files $BIN/MAXTEXT.SYS $BIN/MAXTEXT.COM"
            setup='C:\MAXTEXT /MODE:80x50 > C:\MT.TXT'
        fi
        VGA=$adapter ACCEL=${ACCEL:--accel tcg} TESTDIR="$out" KEEP=1 \
        CONFIG="$config" XFILES="$files" \
        AUTO="@ECHO OFF|$setup|C:\MTSVGA >> C:\MT.TXT|IF ERRORLEVEL 1 ECHO PROBE-FAIL >> C:\MT.TXT|C:\MTUITEST 50 >> C:\MT.TXT|TYPE C:\MT.TXT|ECHO MAXTEXT-SVGA-END" \
        STEPS='wait:MAXTEXT-SVGA-END:60 text:end' \
        bash "$ROOT/linux/test/dosboot.sh" msdos622 > "$ROOT/build/maxtext-svga-$adapter-$driver.log" 2>&1
        mcopy -o -i "$out/test.img@@32256" ::/MT.TXT "$out/MT.TXT"
        python3 - "$out/MT.TXT" "$adapter" <<'PY'
from pathlib import Path
import sys
s = Path(sys.argv[1]).read_text(encoding='cp437')
assert 'MTSVGA PASS: inventory only; geometry unchanged' in s, s
assert 'MTUITEST PASS: 80x50' in s, s
assert 'FAIL' not in s and 'failed' not in s, s
expected = ('ID=1013:00B8' if sys.argv[2] == 'cirrus' else 'ID=1234:1111')
assert expected in s, s
assert '(inventory only)' in s, s
if sys.argv[2] == 'cirrus':
    assert 'Cirrus GD5446' in s, s
else:
    assert 'unclassified' in s and 'Cirrus' not in s, s
PY
        echo "PASS: $adapter PCI inventory, driver $driver, geometry and QUILIB unchanged"
    done
done
# Faults are injected by a separate, test-only device; no test switches in
# MTSVGA itself. Errorlevel is checked exactly using descending DOS tests.
for fault in N S R L D; do
    expected=3
    case "$fault" in N|S) expected=2;; D) expected=1;; esac
    out=$ROOT/build/test-maxtext-svga-fault-$fault
    VGA=std ACCEL=${ACCEL:--accel tcg} TESTDIR="$out" KEEP=1 \
    CONFIG="DEVICE=C:\MTPCIFIX.SYS /$fault|FILES=40" \
    XFILES="$TBIN/MTSVGA.COM $TBIN/MTPCIFIX.SYS $TBIN/MTUITEST.EXE" \
    AUTO="@ECHO OFF|C:\MTSVGA > C:\MT.TXT|IF ERRORLEVEL $((expected+1)) GOTO BAD|IF ERRORLEVEL $expected GOTO OK|:BAD|ECHO ERRORLEVEL-FAIL >> C:\MT.TXT|GOTO END|:OK|ECHO ERRORLEVEL-PASS >> C:\MT.TXT|:END|C:\MTUITEST 25 >> C:\MT.TXT|TYPE C:\MT.TXT|ECHO MAXTEXT-SVGA-END" \
    STEPS='wait:MAXTEXT-SVGA-END:60 text:end' \
    bash "$ROOT/linux/test/dosboot.sh" msdos622 > "$ROOT/build/maxtext-svga-fault-$fault.log" 2>&1
    mcopy -o -i "$out/test.img@@32256" ::/MT.TXT "$out/MT.TXT"
    rg -q 'ERRORLEVEL-PASS' "$out/MT.TXT"
    ! rg -q 'ERRORLEVEL-FAIL|geometry changed|MTSVGA PASS' "$out/MT.TXT"
    rg -q 'MTUITEST PASS: 80x25' "$out/MT.TXT"
    echo "PASS: PCI BIOS fault $fault rejected with exit $expected, geometry unchanged"
done
