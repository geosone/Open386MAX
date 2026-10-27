#!/bin/bash
# Open 386MAX
# Copyright: Open 386MAX contributors 2026.
# GNU General Public License version 3; see LICENSE.
# SPDX-License-Identifier: GPL-3.0-only
#
# Exercise MAX and ASQ under 80x50/60; NO_DRIVER=1 uses BIOS 80x50.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
OUT=$ROOT/build/test-maxtext-tools${NO_DRIVER:+-no-driver}
rows=${ROWS:-50}
case "$rows" in 50|60) ;; *) echo 'ROWS must be 50 or 60' >&2; exit 2;; esac
[ "$rows" = 50 ] || OUT=$OUT-$rows
if [ "${NO_DRIVER:-0}:$rows" = 1:60 ]; then
    echo 'ROWS=60 requires MAXTEXT; the no-driver path uses BIOS 80x50' >&2
    exit 2
fi
mkdir -p "$OUT"
printf 'OLD\r\n' > "$OUT/T.TXT"
BIN=$ROOT/build/bin
TBIN=$ROOT/build/TESTS/MAXTEXT/bin
xfiles="$TBIN/MTUITEST.EXE $BIN/MAX.EXE $BIN/max.hlp $BIN/ASQ.EXE $BIN/asq.hlp $OUT/T.TXT"
if [ "${NO_DRIVER:-0}" = 1 ]; then
    cfg='FILES=40|SHELL=C:\COMMAND.COM C:\ /E:1024 /P'
    setmode='C:\MTUITEST 50 80 BIOS > NUL'
    status='REM QUILIB uses BIOS geometry without MAXTEXT'
    restore='C:\MTUITEST 25 80 BIOS > NUL'
else
    xfiles="$xfiles $BIN/MAXTEXT.SYS $BIN/MAXTEXT.COM"
    cfg='DEVICE=C:\MAX\386MAX.SYS|DOS=HIGH,UMB|DEVICEHIGH=C:\MAXTEXT.SYS|FILES=40|SHELL=C:\COMMAND.COM C:\ /E:1024 /P'
    setmode='C:\MAXTEXT /MODE:80x'"$rows"
    status='C:\MAXTEXT /STATUS >> C:\TOOLS.TXT'
    restore='C:\MAXTEXT /RESTORE'
fi
auto='@ECHO OFF|PATH C:\;C:\MAX|'"$setmode"'|C:\MAX.EXE /E C:\T.TXT|C:\MTUITEST '"$rows"' > C:\TOOLS.TXT|C:\ASQ /S C:\HIGH'"$rows"'.ASQ /D "MAXTEXT" /X|C:\ASQ /L C:\HIGH'"$rows"'.ASQ /W C:\REPORT.TXT /V /X|'"$status"'|C:\MTUITEST '"$rows"' >> C:\TOOLS.TXT|'"$restore"'|TYPE C:\TOOLS.TXT|ECHO MAXTEXT-TOOLS-END'
ACCEL=${ACCEL:--accel tcg} TESTDIR="$OUT/run" KEEP=1 \
XFILES="$xfiles" CONFIG="$cfg" AUTO="$auto" \
STEPS='wait:T.TXT:60 key:n,e,w,esc sleep:1 key:y wait:MAXTEXT-TOOLS-END:120 text:end' \
bash "$ROOT/linux/test/dosboot.sh" msdos622 > "$OUT/boot.log" 2>&1
for name in TOOLS.TXT T.TXT "HIGH$rows.ASQ" REPORT.TXT; do
    mcopy -o -i "$OUT/run/test.img@@32256" "::/$name" "$OUT/$name"
done
python3 - "$OUT" "${NO_DRIVER:-0}" "$rows" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]);s=(p/'TOOLS.TXT').read_text();rows=sys.argv[3]
assert (p/'T.TXT').read_text().strip()=='newOLD'
assert s.count('MTUITEST PASS: 80x'+rows)==2,s
if sys.argv[2]=='0': assert 'VGA rows (0=unknown): '+rows in s,s
assert 'FAIL' not in s,s
snapshot=p/('HIGH'+rows+'.ASQ')
assert snapshot.stat().st_size>100
record=any(line.startswith('MaxText ') for line in snapshot.read_text(encoding='cp437').splitlines())
report=(p/'REPORT.TXT').read_text(encoding='cp437')
assert record==(sys.argv[2]=='0'),record
import re
assert bool(re.search(r'MAXTEXT:\s+API 1\.2',report))==(sys.argv[2]=='0'),report
if sys.argv[2]=='0': assert '80x'+rows+', font 8' in report,report
print('PASS: MAX editor file change, ASQ snapshot, retained 80x'+rows+' geometry' + (' without MAXTEXT' if sys.argv[2]=='1' else ''))
PY
