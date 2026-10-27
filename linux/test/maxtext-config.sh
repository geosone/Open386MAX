#!/bin/bash
# Copyright (C) 2026 Open386MAX contributors. SPDX-License-Identifier: GPL-3.0-only
# Boot-time selection and optional CP437 font. Test sources stay in TESTS.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
BIN=$ROOT/build/bin
TBIN=$ROOT/build/TESTS/MAXTEXT/bin
for dos in "${@:-msdos622}"; do
    for load in low high loader; do
        case "$load" in
        low) cfg='DEVICE=C:\MAXTEXT.SYS /MODE=80x50 /FONT=UNSCII';;
        high) cfg='DEVICE=C:\MAX\386MAX.SYS|DOS=HIGH,UMB|DEVICEHIGH=C:\MAXTEXT.SYS /FONT:UNSCII /MODE:80x50';;
        loader) cfg='DEVICE=C:\MAX\386MAX.SYS|DEVICE=C:\MAX\386LOAD.SYS PROG=C:\MAXTEXT.SYS /MODE=80x50 /FONT=UNSCII';;
        esac
        # This DR-DOS image does not provide working DEVICEHIGH UMB linkage.
        [ "$dos:$load" = edrdos:high ] && continue
        out=$ROOT/build/test-maxtext-config/$dos-$load
        ACCEL=${ACCEL:--accel tcg} TESTDIR="$out" KEEP=1 \
        XFILES="$BIN/MAXTEXT.SYS $BIN/MAXTEXT.COM $TBIN/MTFTEST.COM $TBIN/MTUITEST.EXE" \
        CONFIG="$cfg|FILES=40" \
        AUTO='@ECHO OFF|C:\MAXTEXT /STATUS > C:\MT.TXT|C:\MTFTEST >> C:\MT.TXT|C:\MTUITEST 50 >> C:\MT.TXT|C:\MAXTEXT /RESTORE >> C:\MT.TXT|C:\MTUITEST 25 >> C:\MT.TXT|TYPE C:\MT.TXT|ECHO MAXTEXT-CONFIG-END' \
        STEPS='wait:MAXTEXT-CONFIG-END:60 text:end' \
        bash "$ROOT/linux/test/dosboot.sh" "$dos" > "$ROOT/build/maxtext-config-boot.log" 2>&1
        mcopy -o -i "$out/test.img@@32256" ::/MT.TXT "$out/MT.TXT"
        python3 - "$out" "$load" <<'PY'
from pathlib import Path
import re,sys
s=(Path(sys.argv[1])/'MT.TXT').read_text()
for expected in ['MTFTEST PASS','MTUITEST PASS: 80x50','MTUITEST PASS: 80x25']:
    assert expected in s,s
assert 'FAIL' not in s and 'failed' not in s,s
seg=int(re.search(r'segment \(decimal\): (\d+)',s)[1])
assert (seg<0xa000) if sys.argv[2]=='low' else (0xc000<=seg<0xf000),s
print('PASS: CONFIG mode/font, all glyphs, UMB policy, restore boot geometry')
PY
        printf '%s %s: PASS\n' "$dos" "$load"
    done
done
# Malformed options must reject installation, preserving a working DOS boot.
for opts in '/MODE=80x50 /BOGUS' '/MODE=80x50 /MODE=80x43' '/FONT=UNKNOWN' '/MODE=0x50'; do
    out=$ROOT/build/test-maxtext-config/rejected
    ACCEL=${ACCEL:--accel tcg} TESTDIR="$out" KEEP=1 \
    XFILES="$BIN/MAXTEXT.SYS $BIN/MAXTEXT.COM" CONFIG="DEVICE=C:\MAXTEXT.SYS $opts" \
    AUTO='@ECHO OFF|C:\MAXTEXT /STATUS > C:\MT.TXT|IF ERRORLEVEL 1 ECHO REJECT-PASS >> C:\MT.TXT|TYPE C:\MT.TXT|ECHO MAXTEXT-CONFIG-END' \
    STEPS='wait:MAXTEXT-CONFIG-END:45 text:end' \
    bash "$ROOT/linux/test/dosboot.sh" msdos622 > "$ROOT/build/maxtext-config-reject.log" 2>&1
    mcopy -o -i "$out/test.img@@32256" ::/MT.TXT "$out/MT.TXT"
    rg -q 'REJECT-PASS' "$out/MT.TXT"
    rg -q 'invalid device option' "$out/end.txt"
done
echo 'PASS: malformed/duplicate/unknown CONFIG options rejected'
