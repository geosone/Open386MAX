#!/bin/bash
# Open 386MAX
# Copyright: Open 386MAX contributors 2026.
# GNU General Public License version 3; see LICENSE.
# SPDX-License-Identifier: GPL-3.0-only
#
# Prove QUILIB works without MAXTEXT.SYS: BIOS 80x25/80x50, with/without 386MAX.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
TBIN=$ROOT/build/TESTS/MAXTEXT/bin
for dos in "${@:-msdos622}"; do
    for manager in plain 386max; do
        cfg='FILES=40|SHELL=C:\COMMAND.COM C:\ /E:1024 /P'
        if [ "$manager" = 386max ]; then
            cfg="DEVICE=C:\MAX\386MAX.SYS|DOS=HIGH,UMB|$cfg"
        fi
        out=$ROOT/build/test-maxtext-no-driver/$dos-$manager
        ACCEL=${ACCEL:--accel tcg} TESTDIR="$out" KEEP=1 \
            XFILES="$TBIN/MTUITEST.EXE $TBIN/MTEXAPI.EXE" \
            CONFIG="$cfg" \
            AUTO='@ECHO OFF|C:\MTEXAPI > C:\NODRV.TXT|IF ERRORLEVEL 1 ECHO NO-DRIVER-PASS >> C:\NODRV.TXT|C:\MTUITEST 25 80 BIOS >> C:\NODRV.TXT|C:\MTUITEST 50 80 BIOS >> C:\NODRV.TXT|C:\MTUITEST 25 80 BIOS >> C:\NODRV.TXT|TYPE C:\NODRV.TXT|ECHO QUILIB-NO-DRIVER-END' \
            STEPS='wait:QUILIB-NO-DRIVER-END:45 text:end' \
            bash "$ROOT/linux/test/dosboot.sh" "$dos" > "$ROOT/build/maxtext-no-driver-boot.log" 2>&1
        mcopy -o -i "$out/test.img@@32256" ::/NODRV.TXT "$out/NODRV.TXT"
        python3 - "$out/NODRV.TXT" "$dos" "$manager" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
assert 'MTEXAPI: MAXTEXT not loaded' in s,s
assert 'NO-DRIVER-PASS' in s,s
assert s.count('MTUITEST PASS: 80x25')==2,s
assert s.count('MTUITEST PASS: 80x50')==1,s
assert 'FAIL' not in s,s
print(f'{sys.argv[2]} {sys.argv[3]}: PASS, no MAXTEXT, BIOS 80x25/80x50')
PY
    done
done
