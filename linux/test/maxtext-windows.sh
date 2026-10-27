#!/bin/bash
# Copyright (C) 2026 Open386MAX contributors.
# GNU General Public License version 3; see LICENSE.
# SPDX-License-Identifier: GPL-3.0-only
# Plain WIN from a high text mode, real GUI probe, then DOS video verification.
# VBE_DIR points to an unpacked, separately obtained vbesvga.drv release.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
video=${VIDEO:-vga}
mm=${MM:-386max}
rows=${ROWS:-50}
OUT=$ROOT/build/test-maxtext-windows-$mm-$video-$rows${BOOT_MODE:+-config}${FONT:+-font}
[ "${VGA:-std}" = std ] || OUT=$OUT-${VGA}
BIN=$ROOT/build/bin
TBIN=$ROOT/build/TESTS/MAXTEXT/bin
mkdir -p "$OUT/stage"
cp "$ROOT/build/win311/win311.img" "$OUT/base.img"
P=$OUT/base.img@@32256
mcopy -o -i "$P" ::/WINDOWS/SYSTEM.INI "$OUT/stage/SYSTEM.INI"
mcopy -o -i "$P" ::/WINDOWS/WIN.INI "$OUT/stage/WIN.INI"
python3 - "$OUT/stage" "$video" "$mm" <<'PY'
from pathlib import Path
import re,sys
p=Path(sys.argv[1]); video,mm=sys.argv[2:]
def update(file,section,key,value):
    path=p/file;s=path.read_text(encoding='latin1');lines=s.splitlines()
    current='';result=[];found=False;seen=False
    for line in lines:
        if line.strip().startswith('['):
            if current==section and not found: result.append(key+'='+value);found=True
            current=line.strip()[1:-1].lower()
            if current==section: seen=True
        if current==section and line.split('=',1)[0].strip().lower()==key.lower():
            if not found: result.append(key+'='+value);found=True
        else: result.append(line)
    if current==section and not found: result.append(key+'='+value);found=True
    if not seen: result+=['['+section+']',key+'='+value]
    path.write_bytes(('\r\n'.join(result)+'\r\n').encode('latin1'))
update('WIN.INI','windows','run',r'C:\MAX\MTWIN.EXE')
update('WIN.INI','windows','load','')
if mm=='386max':
    # Unique key for this VxD; do not replace other device= entries.
    path=p/'SYSTEM.INI';s=path.read_text(encoding='latin1')
    s=re.sub(r'(?im)^\[386Enh\]$',lambda m:m[0]+'\ndevice=C:\\MAX\\386MAX.VXD',s)
    path.write_bytes(s.replace('\n','\r\n').encode('latin1'))
if video=='vbe':
    for section,key,value in [('boot','display.drv','VBESVGA.DRV'),
        ('boot','386grabber','VBEVMDIB.3GR'),('386enh','display','VDDVBE.386'),
        ('vbesvga.drv','Width','800'),('vbesvga.drv','Height','600'),
        ('vbesvga.drv','Depth','8')]: update('SYSTEM.INI',section,key,value)
PY
mcopy -o -i "$P" "$OUT/stage/SYSTEM.INI" "$OUT/stage/WIN.INI" ::/WINDOWS/
if [ "$video" = vbe ]; then
    : "${VBE_DIR:?point VBE_DIR at unpacked vbesvga.drv release}"
    for f in VBESVGA.DRV VDDVBE.386 VBEVMDIB.3GR; do
        mcopy -o -i "$P" "$VBE_DIR/$f" ::/WINDOWS/SYSTEM/
    done
fi
if [ "$mm" = 386max ]; then
    cfg='DEVICE=C:\MAX\386MAX.SYS|DOS=HIGH,UMB|DEVICE=C:\MAX\386LOAD.SYS PROG=C:\MAXTEXT.SYS'
else cfg='DEVICE=C:\HIMEM.SYS|DEVICE=C:\MAXTEXT.SYS'; fi
if [ "${BOOT_MODE:-0}" = 1 ]; then
    cfg="$cfg /MODE=80x$rows"
    [ -z "${FONT:-}" ] || cfg="$cfg /FONT=$FONT"
    setmode='REM Mode selected by CONFIG.SYS'
else setmode="C:\MAXTEXT /MODE:80x$rows"; fi
fontcheck='REM Default BIOS font'
fontreturn='REM Default BIOS font'
if [ "${FONT:-}" = UNSCII ]; then
    fontcheck='C:\MTFTEST >> C:\MT.TXT'
    fontreturn='C:\MTFTEST > C:\FONTRET.TXT|IF ERRORLEVEL 1 ECHO WINDOWS-FONT-CHANGED >> C:\MT.TXT|C:\MAXTEXT /MODE:80x'"$rows"'|C:\MTFTEST >> C:\MT.TXT'
fi
# Runtime selection also covers WIN typed after an interactive mode change.
geometryreturn='C:\MTUITEST '"$rows"' >> C:\MT.TXT'
if [ "$rows:${VGA:-std}" = 60:cirrus ]; then
    # The tested VDD restores BIOS mode 3 + 8-pixel font as 50 rows. Record
    # that limitation, insist on usable 50 or 60 rows, and test re-selection.
    geometryreturn='C:\MTUITEST 60 > C:\GEOMRET.TXT|IF NOT ERRORLEVEL 1 GOTO RESTORED|C:\MTUITEST 50 >> C:\GEOMRET.TXT|IF ERRORLEVEL 1 ECHO WINDOWS-GEOMETRY-FAIL >> C:\MT.TXT|ECHO WINDOWS-GEOMETRY-CHANGED >> C:\MT.TXT|C:\MAXTEXT /MODE:80x60|:RESTORED|C:\MTUITEST 60 >> C:\MT.TXT'
fi
auto='@ECHO OFF|PATH C:\;C:\WINDOWS;C:\MAX|'"$setmode"'|C:\MAXTEXT /STATUS > C:\MT.TXT|'"$fontcheck"'|C:\MTUITEST '"$rows"' >> C:\MT.TXT|WIN|C:\MAXTEXT /STATUS >> C:\MT.TXT|'"$geometryreturn"'|'"$fontreturn"'|C:\MAXTEXT /MODE:80x43|C:\MTUITEST 43 >> C:\MT.TXT|TYPE C:\MT.TXT|ECHO MAXTEXT-WIN-END'
ACCEL=${ACCEL:--accel tcg} TESTDIR="$OUT/run" KEEP=1 \
    XFILES="$BIN/MAXTEXT.SYS $BIN/MAXTEXT.COM $TBIN/MTUITEST.EXE $TBIN/MTFTEST.COM $ROOT/build/TESTS/MAXTEXT/WIN/bin/MTWIN.EXE" \
    CONFIG="$cfg|FILES=40|BUFFERS=20|SHELL=C:\COMMAND.COM C:\ /P" AUTO="$auto" \
    STEPS="sleep:${BOOT_WAIT:-30} shot:windows key:ret wait:MAXTEXT-WIN-END:90 text:end" \
    bash "$ROOT/linux/test/dosboot.sh" "$OUT/base.img" > "$OUT/boot.log" 2>&1
for f in WINOK.TXT MT.TXT; do mcopy -o -i "$OUT/run/test.img@@32256" "::/$f" "$OUT/$f"; done
python3 - "$OUT" "$rows" "$video" "${FONT:-}" <<'PY'
from pathlib import Path
import sys
out=Path(sys.argv[1]);rows=sys.argv[2];video=sys.argv[3]
s=(out/'MT.TXT').read_text();w=(out/'WINOK.TXT').read_text()
assert 'MTWIN PASS: Windows' in w,w
assert s.count('MTUITEST PASS: 80x'+rows)==2,s
assert 'MTUITEST PASS: 80x43' in s,s
assert 'FAIL' not in s,s
if sys.argv[4]=='UNSCII':
    assert s.count('MTFTEST PASS')==2,s
    if 'WINDOWS-FONT-CHANGED' in s:
        print('NOTE: Windows replaced the font; a subsequent mode request restored Unscii')
if video=='vbe': assert '800x600x8' in w and 'VBESVGA.DRV' in w.upper(),w
if 'WINDOWS-GEOMETRY-CHANGED' in s:
    print('LIMITATION: Windows returned at 50 rows; explicit MAXTEXT mode request restored native 60 rows')
print('PASS: plain WIN startup, '+video+' GUI, DOS geometry/re-selection checks and subsequent mode switch')
PY
