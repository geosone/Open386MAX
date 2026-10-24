#!/bin/bash
# Open 386MAX
# Copyright: Open 386MAX contributors 2026.
# GNU General Public License version 3; see LICENSE.
# SPDX-License-Identifier: GPL-3.0-only
#
# MAXTEXT VGA mode/API/UI and rollback tests using existing DOS images and dosboot.sh.
# bash linux/test/maxtext.sh [msdos622 freedos edrdos]
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
BIN=$ROOT/build/bin
TBIN=$ROOT/build/TESTS/MAXTEXT/bin
export ACCEL=${ACCEL:--accel tcg}
export MTOOLS_SKIP_CHECK=1
boot() {
    local dos=$1 name=$2 config=$3 auto=$4
    local out=$ROOT/build/test-maxtext/$dos-$name
    TESTDIR="$out" KEEP=1 XFILES="$BIN/MAXTEXT.SYS $BIN/MAXTEXT.COM $TBIN/MTTEST.COM $TBIN/MTUITEST.EXE $TBIN/MTEXAPI.EXE" \
        CONFIG="$config|FILES=40|SHELL=C:\COMMAND.COM C:\ /E:1024 /P" \
        AUTO="@ECHO OFF|$auto|ECHO MAXTEXT-END|TYPE C:\MT.TXT" \
        STEPS="wait:MAXTEXT-END:45 text:end mon:memsave+0+0x100000+\"$out/memory.bin\"" \
        bash "$ROOT/linux/test/dosboot.sh" "$dos" > "$ROOT/build/maxtext-boot.log" 2>&1
    mcopy -o -i "$out/test.img@@32256" ::/MT.TXT "$out/MT.TXT"
    tr -d '\r' < "$out/MT.TXT" > "$out/result.txt"
    printf '%s %s: ' "$dos" "$name"
}
check_installed() {
    local out=$ROOT/build/test-maxtext/$1-$2/result.txt
    rg -q 'MTTEST PASS' "$out"
    rg -q '^80x25' "$out"
    rg -q '^80x43' "$out"
    rg -q '^80x50' "$out"
    for rows in 25 43 50; do
        rg -q "MTUITEST PASS: 80x$rows" "$out"
    done
    rg -q 'MTEXAPI PASS' "$out"
    if rg -q 'FAIL|mode change failed|cannot allocate' "$out"; then cat "$out"; return 1; fi
    rg -q 'MODE-REJECT-PASS' "$out"
    rg -q 'BDA mode: 3, columns: 80, VGA rows .*25' "$out"
    python3 - "$out" "$2" <<'PY'
from pathlib import Path
import re, struct, sys
s = open(sys.argv[1]).read()
m = re.search(r'resident segment \(decimal\): (\d+), bytes: (\d+)', s)
assert m, s
segment, size = map(int, m.groups())
assert 0 < size < 8192, size
assert (0xA000 <= segment < 0xF000) if sys.argv[2] != 'low' else segment < 0xA000
memory = Path(sys.argv[1]).with_name('memory.bin').read_bytes()
base = segment * 16
assert memory[base+10:base+18] == b'MAXTEXT$'
assert struct.unpack_from('<H', memory, base+4)[0] == 0xC800
assert memory[base:base+4] != b'\xff\xff\xff\xff', 'not linked in DOS device chain'
print(f'PASS, segment={segment:04X}, resident={size} bytes')
PY
}
AUTO_TEST='C:\MTTEST > C:\MT.TXT|C:\MAXTEXT /LIST >> C:\MT.TXT|C:\MAXTEXT /MODE:80x25 >> C:\MT.TXT|C:\MTUITEST 25 >> C:\MT.TXT|C:\MAXTEXT /MODE:80x43 >> C:\MT.TXT|C:\MTUITEST 43 >> C:\MT.TXT|C:\MTEXAPI 50 >> C:\MT.TXT|C:\MTUITEST 50 >> C:\MT.TXT|C:\MAXTEXT /RESTORE >> C:\MT.TXT|C:\MAXTEXT /STATUS >> C:\MT.TXT|C:\MAXTEXT /MODE:132x60 >> C:\MT.TXT|IF ERRORLEVEL 2 ECHO MODE-REJECT-PASS >> C:\MT.TXT'
for dos in "${@:-msdos622}"; do
    boot "$dos" low 'DEVICE=C:\MAXTEXT.SYS' "$AUTO_TEST"
    check_installed "$dos" low
    if [ "$dos" = edrdos ]; then
        # This kernel/386MAX combination falls back to low memory with
        # DEVICEHIGH; exercise the existing 386MAX device loader instead.
        boot "$dos" umb 'DEVICE=C:\MAX\386MAX.SYS|DEVICE=C:\MAX\386LOAD.SYS PROG=C:\MAXTEXT.SYS' "$AUTO_TEST"
    else
        boot "$dos" umb 'DEVICE=C:\MAX\386MAX.SYS|DOS=HIGH,UMB|DEVICEHIGH=C:\MAXTEXT.SYS' "$AUTO_TEST"
    fi
    check_installed "$dos" umb
    boot "$dos" rejected 'DEVICE=C:\MAXTEXT.SYS /MODE=132x60' 'C:\MAXTEXT /STATUS > C:\MT.TXT|IF ERRORLEVEL 1 ECHO REJECT-PASS >> C:\MT.TXT'
    rg -q 'REJECT-PASS' "$ROOT/build/test-maxtext/$dos-rejected/result.txt"
    rg -q 'no device options supported' "$ROOT/build/test-maxtext/$dos-rejected/end.txt"
    echo PASS
done
boot msdos622 loader 'DEVICE=C:\MAX\386MAX.SYS|DEVICE=C:\MAX\386LOAD.SYS PROG=C:\MAXTEXT.SYS' "$AUTO_TEST"
check_installed msdos622 loader
boot msdos622 missing '' 'C:\MAXTEXT /STATUS > C:\MT.TXT|IF ERRORLEVEL 1 ECHO MISSING-PASS >> C:\MT.TXT'
rg -q 'MISSING-PASS' "$ROOT/build/test-maxtext/msdos622-missing/result.txt"
echo PASS
